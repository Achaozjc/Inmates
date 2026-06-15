--!strict
local RunService = game:GetService("RunService")

-- 核心参数配置 --
local COLOR_RANGE = 10 -- 每个色带上包含的色点数量
local FLOW_SPEED = 2 -- 流动速度 (建议1.0-2.0)

local UI_Rainbow = {}
UI_Rainbow.__index = UI_Rainbow

-- 静态变量管理所有实例
local activeInstances = {} :: { ClassType }
local renderConnection: RBXScriptConnection? = nil

export type ClassType = typeof(setmetatable(
	{} :: {
		_instance: UIGradient,
	},
	UI_Rainbow
))

-- 集中更新函数
local function updateAll()
	-- 每一帧只计算一次 ColorSequence
	local loop = os.clock() % FLOW_SPEED / FLOW_SPEED
	local colors = {}

	for i = 1, COLOR_RANGE + 1, 1 do
		local keypoint
		local hue = loop - ((i - 1) / COLOR_RANGE)

		if hue < 0 then
			hue = hue + 1
		end

		keypoint = Color3.fromHSV(hue, 0.6, 1)

		-- ColorSequenceKeypoint requires time to be between 0 and 1
		local timePos = (i - 1) / COLOR_RANGE
		-- clamp to be safe, though logic suggests it should be fine
		if timePos > 1 then
			timePos = 1
		end
		if timePos < 0 then
			timePos = 0
		end

		table.insert(colors, ColorSequenceKeypoint.new(timePos, keypoint))
	end

	local colorSequence = ColorSequence.new(colors)

	-- 批量应用
	for _, instance in activeInstances do
		if instance._instance then
			instance._instance.Color = colorSequence
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

function UI_Rainbow.new(parent: GuiObject): ClassType
	local self = {
		_instance = Instance.new("UIGradient"),
	}
	setmetatable(self, UI_Rainbow)

	self._instance.Rotation = parent:GetAttribute("Rotation") :: number or 45
	self._instance.Parent = parent

	self:_setup()

	return self
end

function UI_Rainbow._setup(self: ClassType)
	table.insert(activeInstances, self)
	startLoop()
end

function UI_Rainbow.destroy(self: ClassType)
	local index = table.find(activeInstances, self)
	if index then
		table.remove(activeInstances, index)
		stopLoop()
	end
	if self._instance then
		self._instance:Destroy()
	end
end

return UI_Rainbow
