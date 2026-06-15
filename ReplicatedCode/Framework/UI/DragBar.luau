local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Connections = require(ReplicatedStorage.ReplicatedCode.Framework.Infrastructure.Classes.Connections)

local Signal = require(ReplicatedStorage.ReplicatedCode.Framework.Packages.Signal)
local Janitor = require(ReplicatedStorage.ReplicatedCode.Framework.Packages.Janitor)

local getInstance = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Instance.GetInstance)
local getCodeAsset = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Instance.GetCodeAsset)
local prefabFolder: Folder = getCodeAsset("UI", "DragBar")
local DragBarPre = (getInstance(prefabFolder, "DragBar") :: any) :: Frame
local Network = require(ReplicatedStorage.ReplicatedCode.Framework.Core.Network)
local RemoteFunctionName = require(ReplicatedStorage.ReplicatedCode.Framework.Core.Network.RemoteName.RemoteFunctionName)


local MIN_VALUE = 0
local MAX_VALUE = 100


local DragBar = {}
DragBar.__index = DragBar

export type ClassType = typeof(setmetatable(
	{} :: {
		_connections: Connections.ClassType,
		_instance: Frame,
		_janitor: Janitor.Janitor,
	

		uiDragDetector :UIDragDetector,
		_value: number,

		
		_change: Signal.ClassType,
		_uiScale :UIScale,
		
		MIN_SCALE_OFFSET: number,
		MAX_SCALE_OFFSET: number,
		
		
		maxValue :number,
		minValue :number,
		stepValue :number,
	
		_key: string?,
		_suffix: string,
	
	},
	DragBar
))

function DragBar.new(key:string?, info: {min:number?, max:number?, step:number?, suffix:string?}, uiScale: UIScale, instance: GuiObject?): ClassType
	local self = {}
	setmetatable(self, DragBar)
	
	self._key = key or nil
	
	self._instance = instance or DragBarPre:Clone()
	self._connections = Connections.new()
	self._janitor = Janitor.new()
	
	self._change = Signal.new()

	self._drag = self._instance:FindFirstChild("Holder"):FindFirstChild("SliderContainer"):FindFirstChild("Drag")
	
	self.uiDragDetector = self._drag:FindFirstChild("UIDragDetector") ::UIDragDetector
	self.valueDisplay = self._instance:FindFirstChild("Amount") ::TextLabel


	self._uiScale = uiScale
	
	self.MIN_SCALE_OFFSET = 0
	self.MAX_SCALE_OFFSET = 0  
		
	
	self.minValue = info.min or MIN_VALUE
	self.maxValue = info.max or MAX_VALUE
	self.stepValue = info.step or 1
	self._suffix = info.suffix or ""
	
	self._value = 0
	
	

	return self
end


function DragBar.setValues(self: ClassType, info: {min:number?, max:number?, step:number?, suffix:string?})
	self.minValue = info.min or self.minValue
	self.maxValue = info.max or self.maxValue
	self.stepValue = info.step or self.stepValue
	self._suffix = info.suffix or self._suffix
end



function DragBar.setup(self: ClassType)
	local parentSize = (self._drag.Parent.AbsoluteSize - self._drag.AbsoluteSize) / self._uiScale.Scale -- slide - drag / scale

	local maxSizeX = parentSize.X / 2

	self.MIN_SCALE_OFFSET = -maxSizeX
	self.MAX_SCALE_OFFSET = maxSizeX
end

function DragBar._snapValue(self: ClassType, value: number): number
	local clampedValue = math.clamp(value, self.minValue, self.maxValue)
	local stepValue = math.max(self.stepValue, 1)
	local steppedValue = self.minValue + math.round((clampedValue - self.minValue) / stepValue) * stepValue
	return math.clamp(steppedValue, self.minValue, self.maxValue)
end

function DragBar._setDragPositionFromValue(self: ClassType, value: number)
	if self.maxValue == self.minValue then
		return
	end

	local normalizedValue = (value - self.minValue) / (self.maxValue - self.minValue)
	local positionOffset = self.MIN_SCALE_OFFSET + normalizedValue * (self.MAX_SCALE_OFFSET - self.MIN_SCALE_OFFSET)
	self.uiDragDetector.DragUDim2 = UDim2.new(
		0,
		positionOffset,
		self.uiDragDetector.DragUDim2.Y.Scale,
		self.uiDragDetector.DragUDim2.Y.Offset
	)
	self._drag.Position = UDim2.new(0.5, positionOffset, 0.5, 0)
end


function DragBar._setParent(self: ClassType, parent)
	self._instance.Parent = parent
	self:setup()
	self:init()
end



function DragBar.init(self: ClassType)
	local UIStroke = self._drag:FindFirstChildWhichIsA("UIStroke")
	
	local DragContinue = self.uiDragDetector.DragContinue:Connect(function()

		local xOffset = self.uiDragDetector.DragUDim2.X.Offset
		local adjustedOffset = math.clamp(xOffset, self.MIN_SCALE_OFFSET, self.MAX_SCALE_OFFSET)

		-- 计算 scale
		local scale = (adjustedOffset - self.MIN_SCALE_OFFSET) / (self.MAX_SCALE_OFFSET - self.MIN_SCALE_OFFSET)

		-- 限制 scale 在 [0, 1] 范围内
		scale = math.clamp(scale, 0, 1)

		-- 四舍五入处理
		local scaledValue = scale * 100  -- 放大
		local roundedValue = math.round(scaledValue) -- 四舍五入
		local newScale = roundedValue / 100 * self.maxValue  -- 还原

		newScale = self.minValue + scale * (self.maxValue - self.minValue)

		self:_displayValue(newScale)
	
	end)

	
	
	local DragStart  = self.uiDragDetector.DragStart:Connect(function(inputPosition)
		UIStroke.Thickness = 5
	end)
	
	
	local DragEnd  = self.uiDragDetector.DragEnd:Connect(function(inputPosition)
		UIStroke.Thickness = 2
		self:_set(self._value)
		if self._key then
			Network.invokeServerAsync(RemoteFunctionName.Change_Settings,self._key, self._value)	
		end	
		SoundService.SFX.Select2:Play()
	end)
	
	self._connections:add(DragContinue, DragStart,  DragEnd)
end


function DragBar._displayValue(self: ClassType, value: number)
	self._value = self:_snapValue(value)
	self:_setDragPositionFromValue(self._value)
	
	self.valueDisplay.Text = tostring(math.clamp(self._value, self.minValue, self.maxValue)) .. self._suffix
	
	self._change:Fire(self._value)
end




function DragBar._set(self: ClassType, value: number)

	-- 确保传入值在最小值和最大值之间
	local clampedValue = self:_snapValue(value)

	-- 计算相对位置
	local normalizedValue = (clampedValue - self.minValue) / (self.maxValue - self.minValue) -- [0, 1]
	local positionOffset = self.MIN_SCALE_OFFSET + normalizedValue * (self.MAX_SCALE_OFFSET - self.MIN_SCALE_OFFSET)

	-- 更新拖动条的位置
	self.uiDragDetector.DragUDim2 = UDim2.new(0, positionOffset, self.uiDragDetector.DragUDim2.Y.Scale, self.uiDragDetector.DragUDim2.Y.Offset)

	-- 更新 _drag 的位置
	self._drag.Position = UDim2.new(0.5, positionOffset, 0.5, 0) -- 设置 _drag 的位置

	-- 显示当前值
	self:_displayValue(clampedValue)
end


function DragBar.destroy(self: ClassType)
	self._janitor:Destroy()
	self._connections:disconnect()
	self._change:DisconnectAll()
	self._instance:Destroy()
end

return DragBar

