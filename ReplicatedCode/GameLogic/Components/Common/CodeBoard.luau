--!strict

--[[
	CodeBoard
	世界中的兑换码展示板（SurfaceGui）Binder 组件（客户端）。
	标签：CodeBoard —— 给世界里的 BasePart 打上该 CollectionService 标签即可生成展示板。

	功能：
	  · 克隆预制体 Instances.Prefabs.Gui.CodeBoard 到 BasePart 上，
	    按点赞门槛（voteTarget）从低到高生成 code 行
	  · 已解锁的 code 直接显示 code 文本（绿色，满进度条）
	  · 未解锁的显示「X likes」目标，并按当前全局点赞数显示进度条
	  · 已达到门槛但尚未由服务端正式 release 的行会被移除（与 LikesCodesGui 行为一致）

	数据来源：CodeController（getLikes / getReleasedList / changed），配置：CodeRewardConfig。

	预制体结构（ReplicatedStorage.Instances.Prefabs.Gui.CodeBoard）：
	  CodeBoard (SurfaceGui)
	  └─ List (ScrollingFrame) + UIListLayout + UIPadding
	     └─ Template (Frame, Visible=false)
	        ├─ Bar (Frame) + UIGradient        —— 进度填充
	        └─ CodeLabel (TextLabel) + UIGradient —— 文本（颜色随状态切换）
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = ReplicatedStorage.ReplicatedCode.Framework
local GameLogic = ReplicatedStorage.ReplicatedCode.GameLogic

local Janitor = require(Framework.Packages.Janitor)
local ShowUnitNum = require(Framework.UI.ShowUnitNum)
local CodeController = require(GameLogic.Controllers.CodeController)
local CodeRewardConfig = require(GameLogic.Shared.Configs.CodeRewardConfig)

local PREFAB = ReplicatedStorage:WaitForChild("Instances")
	:WaitForChild("Prefabs")
	:WaitForChild("Gui")
	:WaitForChild("CodeBoard") :: SurfaceGui

local RELEASED_GRADIENT = ColorSequence.new(Color3.fromRGB(85, 255, 127))
local LOCKED_GRADIENT = ColorSequence.new(Color3.new(1, 1, 1))

local CodeBoard = {}
CodeBoard.__index = CodeBoard

type CodeRow = {
	code: string,
	voteTarget: number,
	row: Frame,
}

export type ClassType = typeof(setmetatable({} :: {
	_part: BasePart,
	_listFrame: ScrollingFrame,
	_template: Frame,
	_rows: { CodeRow },
	_janitor: typeof(Janitor.new()),
}, CodeBoard))

-- 按点赞门槛升序返回需要展示的 code（voteTarget 为 nil/<=0 的默认可用码不进度板）
local function getSortedCodeEntries(): { { code: string, voteTarget: number } }
	local entries: { { code: string, voteTarget: number } } = {}
	for code, info in pairs(CodeRewardConfig.Codes) do
		local voteTarget = tonumber(info.voteTarget)
		if voteTarget and voteTarget > 0 then
			table.insert(entries, {
				code = string.lower(code),
				voteTarget = voteTarget,
			})
		end
	end
	table.sort(entries, function(a, b)
		return a.voteTarget < b.voteTarget
	end)
	return entries
end

function CodeBoard.new(instance: Instance): ClassType?
	if not instance:IsA("BasePart") then
		warn("[CodeBoard] 实例不是 BasePart：", instance:GetFullName())
		return nil
	end
	local part = instance :: BasePart

	local janitor = Janitor.new()

	local gui = PREFAB:Clone()
	gui.Parent = part
	janitor:Add(gui, "Destroy")

	local list = gui:WaitForChild("List") :: ScrollingFrame
	local template = list:WaitForChild("Template") :: Frame

	local self = setmetatable({
		_part = part,
		_listFrame = list,
		_template = template,
		_rows = {},
		_janitor = janitor,
	}, CodeBoard) :: any

	self:_buildCodeList()

	self._janitor:Add(CodeController.changed:Connect(function()
		self:_refreshRows()
	end), "Disconnect")
	self:_refreshRows()
	CodeController.requestStateAsync()

	return self
end

function CodeBoard._buildCodeList(self: ClassType)
	local entries = getSortedCodeEntries()
	for index, entry in ipairs(entries) do
		local row = self._template:Clone()
		row.Name = "Template_" .. index
		row.LayoutOrder = index
		row.Visible = true

		local codeLabel = row:FindFirstChild("CodeLabel") :: TextLabel?
		if codeLabel then
			codeLabel.Text = "loading..."
		end

		row.Parent = self._listFrame
		table.insert(self._rows, {
			code = entry.code,
			voteTarget = entry.voteTarget,
			row = row,
		})
	end
end

function CodeBoard._refreshRows(self: ClassType)
	local likes = CodeController.getLikes()
	local releasedSet: { [string]: boolean } = {}
	for _, code in ipairs(CodeController.getReleasedList()) do
		releasedSet[code] = true
	end

	for _, item in ipairs(self._rows) do
		if not item.row.Parent then
			continue
		end

		local codeLabel = item.row:FindFirstChild("CodeLabel") :: TextLabel?
		local bar = item.row:FindFirstChild("Bar") :: Frame?
		if not codeLabel or not bar then
			continue
		end

		local gradient = codeLabel:FindFirstChild("UIGradient") :: UIGradient?
		if releasedSet[item.code] then
			codeLabel.Text = item.code
			if gradient then
				gradient.Color = RELEASED_GRADIENT
			end
			bar.Size = UDim2.fromScale(1, 1)
		elseif likes >= item.voteTarget then
			item.row:Destroy()
		else
			codeLabel.Text = string.format("%s likes", ShowUnitNum(item.voteTarget))
			if gradient then
				gradient.Color = LOCKED_GRADIENT
			end
			bar.Size = UDim2.fromScale(math.clamp(likes / item.voteTarget, 0, 1), 1)
		end
	end
end

function CodeBoard.destroy(self: ClassType)
	self._janitor:Destroy()
	table.clear(self._rows)
end

return CodeBoard
