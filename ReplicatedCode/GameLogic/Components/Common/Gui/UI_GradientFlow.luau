--!strict
--[[
	Binder 只会调用 new(被标签的实例)，没有第二参数。
	周期等在 Inspector 里配置：在 UIGradient 或其父级 GuiObject 上设 **FlowPeriod**（number，秒，>0）。
	代码里 require 后手动创建仍可传 options.period / options.colors，会覆盖属性里的周期。
]]
local RunService = game:GetService("RunService")

-- Roblox ColorSequence 最多 20 个关键帧，超出会报错
local MAX_COLOR_KEYPOINTS = 20

-- 未配置 FlowPeriod 且未传 options.period 时的整圈时长（秒）
local DEFAULT_PERIOD = 3

local UI_GradientFlow = {}
UI_GradientFlow.__index = UI_GradientFlow

local activeInstances = {} :: { ClassType }
local renderConnection: RBXScriptConnection? = nil

export type Options = {
	period: number?,
	colors: { Color3 }?,
}

export type ClassType = typeof(setmetatable(
	{} :: {
		_gradient: UIGradient,
		_sourceSequence: ColorSequence,
		_period: number,
		_flowPeriodConns: { RBXScriptConnection },
	},
	UI_GradientFlow
))

-- 在给定 u∈[0,1) 处按 ColorSequence 关键帧时间插值（与条带上关键帧分布一致，适配 ColorEnum.RarityColor 等非均匀色标）
local function evalColorAt(sequence: ColorSequence, u: number): Color3
	local kps = sequence.Keypoints
	local n = #kps
	if n == 0 then
		return Color3.new(1, 1, 1)
	end
	if n == 1 then
		return kps[1].Value
	end

	u = u % 1
	if u < 0 then
		u += 1
	end

	if u <= kps[1].Time then
		return kps[1].Value
	end
	if u >= kps[n].Time then
		return kps[n].Value
	end

	for i = 1, n - 1 do
		local t0, t1 = kps[i].Time, kps[i + 1].Time
		if u >= t0 and u <= t1 then
			local span = t1 - t0
			local alpha = if span > 0 then (u - t0) / span else 0
			return kps[i].Value:Lerp(kps[i + 1].Value, alpha)
		end
	end

	return kps[n].Value
end

local function buildFlowingSequence(source: ColorSequence, phase: number): ColorSequence
	local keypoints = table.create(MAX_COLOR_KEYPOINTS)
	for i = 1, MAX_COLOR_KEYPOINTS do
		local t = if MAX_COLOR_KEYPOINTS > 1 then (i - 1) / (MAX_COLOR_KEYPOINTS - 1) else 0
		local c = evalColorAt(source, (t + phase) % 1)
		keypoints[i] = ColorSequenceKeypoint.new(t, c)
	end
	return ColorSequence.new(keypoints)
end

local function colorAtListIndex(colors: { Color3 }, u: number): Color3
	local n = #colors
	if n == 0 then
		return Color3.new(1, 1, 1)
	end
	if n == 1 then
		return colors[1]
	end
	local x = math.clamp(u, 0, 1) * (n - 1) + 1
	local i0 = math.floor(x)
	local i1 = math.min(i0 + 1, n)
	local frac = x - i0
	return colors[i0]:Lerp(colors[i1], frac)
end

local function sequenceFromColorList(colors: { Color3 }): ColorSequence
	local n = #colors
	if n == 0 then
		return ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
		})
	end
	if n == 1 then
		local c = colors[1]
		return ColorSequence.new({
			ColorSequenceKeypoint.new(0, c),
			ColorSequenceKeypoint.new(1, c),
		})
	end

	local count = math.min(n, MAX_COLOR_KEYPOINTS)
	local kps = table.create(count)
	if n <= MAX_COLOR_KEYPOINTS then
		for i = 1, n do
			local t = (i - 1) / (n - 1)
			kps[i] = ColorSequenceKeypoint.new(t, colors[i])
		end
	else
		for i = 1, MAX_COLOR_KEYPOINTS do
			local t = (i - 1) / (MAX_COLOR_KEYPOINTS - 1)
			kps[i] = ColorSequenceKeypoint.new(t, colorAtListIndex(colors, t))
		end
	end
	return ColorSequence.new(kps)
end

local function assertUIGradient(instance: Instance): UIGradient
	if instance:IsA("UIGradient") then
		return instance
	end
	error(("[UI_GradientFlow] 标签只应对 UIGradient 使用，当前为 %s"):format(instance.ClassName))
end

-- 从渐变或父级 Gui 读 FlowPeriod（Binder 下用属性配置周期；UIGradient 本身不是 GuiObject）
local function readPeriodFromGradient(gradient: UIGradient): number
	local v = gradient:GetAttribute("FlowPeriod")
	if typeof(v) == "number" and (v :: number) > 0 then
		return v :: number
	end
	local parent = gradient.Parent
	if parent and parent:IsA("GuiObject") then
		v = parent:GetAttribute("FlowPeriod")
		if typeof(v) == "number" and (v :: number) > 0 then
			return v :: number
		end
	end
	return DEFAULT_PERIOD
end

local function resolvePeriod(gradient: UIGradient, options: Options?): number
	if options and options.period and options.period > 0 then
		return options.period
	end
	return readPeriodFromGradient(gradient)
end

local function resolveSourceSequence(gradient: UIGradient, options: Options?): ColorSequence
	if options and options.colors then
		return sequenceFromColorList(options.colors)
	end
	return gradient.Color
end

local function updateAll()
	for _, inst in activeInstances do
		local g = inst._gradient
		if g.Parent ~= nil then
			local phase = (os.clock() / inst._period) % 1
			g.Color = buildFlowingSequence(inst._sourceSequence, phase)
		end
	end
end

local function startLoop()
	if not renderConnection then
		renderConnection = RunService.RenderStepped:Connect(updateAll)
	end
end

local function stopLoop()
	if renderConnection and #activeInstances == 0 then
		renderConnection:Disconnect()
		renderConnection = nil
	end
end

-- instance：Binder 下为打了标签的 UIGradient。options 仅在使用 require 手动 new 时传入。
function UI_GradientFlow.new(instance: Instance, options: Options?): ClassType
	local gradient = assertUIGradient(instance)
	local flowPeriodConns: { RBXScriptConnection } = {}

	local self = {
		_gradient = gradient,
		_sourceSequence = resolveSourceSequence(gradient, options),
		_period = resolvePeriod(gradient, options),
		_flowPeriodConns = flowPeriodConns,
	}
	setmetatable(self, UI_GradientFlow)

	local function refreshPeriodFromAttributes()
		if options and options.period and options.period > 0 then
			return
		end
		self._period = readPeriodFromGradient(gradient)
	end

	table.insert(flowPeriodConns, gradient:GetAttributeChangedSignal("FlowPeriod"):Connect(refreshPeriodFromAttributes))
	local parent = gradient.Parent
	if parent and parent:IsA("GuiObject") then
		table.insert(flowPeriodConns, parent:GetAttributeChangedSignal("FlowPeriod"):Connect(refreshPeriodFromAttributes))
	end

	table.insert(activeInstances, self)
	startLoop()

	return self
end

function UI_GradientFlow.destroy(self: ClassType)
	for _, c in self._flowPeriodConns do
		c:Disconnect()
	end
	table.clear(self._flowPeriodConns)

	local index = table.find(activeInstances, self)
	if index then
		table.remove(activeInstances, index)
		stopLoop()
	end
end

return UI_GradientFlow
