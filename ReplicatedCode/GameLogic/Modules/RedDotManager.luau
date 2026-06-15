--!strict
--[[
	RedDotManager — 客户端红点响应式核心。

	用法：
	  1. RedDotConditions.registerAll()   -- 注册所有条件（在 start 之前）
	  2. RedDotManager.start()            -- 初始求值 + 订阅 PlayerDataClient.updated
	  3. RedDotManager.bind(key, button)  -- 将按钮的 "RedDot" 子级绑定到状态
	  4. RedDotManager.evaluate(key)      -- 手动触发重新求值（如打开图鉴后消红点）

	Condition 结构：
	  { deps: { PlayerDataKey... }, check: () -> boolean }
	  deps  — 哪些 PlayerDataKey 变化时重新执行 check
	  check — 返回 true 则显示红点
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataClient = require(ReplicatedStorage.ReplicatedCode.Framework.DataStore.PlayerDataClient)
local Signal = require(ReplicatedStorage.ReplicatedCode.Framework.Packages.Signal)

export type Condition = {
	deps: { string },
	check: () -> (boolean | number),
}

local _conditions: { [string]: Condition } = {}
local _signals: { [string]: any } = {}   -- Signal<{ visible: boolean, count: number }>
local _states: { [string]: boolean } = {}
local _counts: { [string]: number } = {}
local _started = false

local RedDotManager = {}

-- 注册一个红点条件，必须在 start() 之前调用
function RedDotManager.register(key: string, condition: Condition)
	_conditions[key] = condition
	_signals[key] = Signal.new()
	_states[key] = false
	_counts[key] = 0
end

-- 重新执行 key 对应的 check，状态或数量变化时通知所有绑定
function RedDotManager.evaluate(key: string)
	local cond = _conditions[key]
	if not cond then
		return
	end
	local ok, result = pcall(cond.check)
	local newCount = 0
	local newState = false
	if ok then
		if type(result) == "number" then
			newCount = math.max(math.floor(result), 0)
			newState = newCount > 0
		else
			newState = result == true
			newCount = if newState then 1 else 0
		end
	end
	if newState ~= _states[key] or newCount ~= _counts[key] then
		_states[key] = newState
		_counts[key] = newCount
		_signals[key]:Fire({
			visible = newState,
			count = newCount,
		})
	end
end

-- 读取当前状态（不触发求值）
function RedDotManager.get(key: string): boolean
	return _states[key] or false
end

-- 读取当前数量（默认 0）
function RedDotManager.getCount(key: string): number
	return _counts[key] or 0
end

-- 将 parent 下名为 "RedDot" 的子级绑定到 key 的状态；立即同步一次
function RedDotManager.bind(key: string, parent: GuiObject)
	local sig = _signals[key]
	if not sig then
		return
	end
	local dot = parent:FindFirstChild("RedDot") :: GuiObject?
	if not dot then
		return
	end
	local countLabel = (dot:FindFirstChild("TextLabel") or dot:FindFirstChild("Count")) :: TextLabel?
	local function _apply(visible: boolean, count: number)
		dot.Visible = visible
		if countLabel then
			if visible then
				countLabel.Text = tostring(math.max(count, 1))
			else
				countLabel.Text = ""
			end
		end
	end

	_apply(_states[key] or false, _counts[key] or 0)
	sig:Connect(function(payload: { visible: boolean, count: number })
		_apply(payload.visible, payload.count)
	end)
end

-- 初始求值全部 key，并订阅 PlayerDataClient.updated；只执行一次
function RedDotManager.start()
	if _started then
		return
	end
	_started = true

	for key in _conditions do
		RedDotManager.evaluate(key)
	end

	PlayerDataClient.updated:Connect(function(dataKey: string)
		for key, cond in _conditions do
			if table.find(cond.deps, dataKey) then
				RedDotManager.evaluate(key)
			end
		end
	end)
end

return RedDotManager
