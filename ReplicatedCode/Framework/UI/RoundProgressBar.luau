--!strict


local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")


local getInstance = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Instance.GetInstance)
local getCodeAsset = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Instance.GetCodeAsset)
local prefabFolder: Folder = getCodeAsset("UI", "RoundProgressBar")
local prefabInstance: Frame = (getInstance(prefabFolder, "RoundProgressBar") :: any) :: Frame

local UPDATE_INTERVAL_SECONDS = 1 -- The interval at which all timers are updated

local TweenInfo = TweenInfo.new(UPDATE_INTERVAL_SECONDS, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)



local RoundProgressBar = {}
RoundProgressBar.__index = RoundProgressBar

export type ClassType = typeof(setmetatable(
	{} :: {
		_instance: Frame,

		_isEnabled: boolean,
	
		_connect: RBXScriptConnection?,
		
		_start: number,
		_end: number,
		_remaining: number,
		
		_rightMask: Frame,
		_leftMask: Frame,
		
		_lastUpdate: number,
		
	},
	RoundProgressBar
))

function RoundProgressBar.new(_start: number, _end: number): ClassType
	local self = {
		_instance = prefabInstance:Clone() :: Frame,
	
		_isEnabled = false,
		
		_start = _start,
		
		_end = _end,
		
		_remaining = _end,
		
		_lastUpdate = 0	
	}
	setmetatable(self, RoundProgressBar)
		
	self._rightMask = getInstance(self._instance, "Right", "Mask"):: Frame
	self._leftMask = getInstance(self._instance, "Left", "Mask"):: Frame

	return self
end

function RoundProgressBar.setVolume(self: ClassType, volume: number)
	self._end = volume
end


function RoundProgressBar.setRemaining(self: ClassType, remaining: number)
	self._remaining = remaining
	self:_update()
end

function RoundProgressBar.getPercent(self: ClassType)
	local percent = 1 - self._remaining / (self._end - self._start)
	return math.clamp(percent, 0, 1)
end


function RoundProgressBar.setParent(self: ClassType, parent: Instance, size :UDim2?)
	self._instance.Parent = parent
	self._instance.Size = size or prefabInstance.Size
end


function RoundProgressBar._update(self: ClassType)
	local percent = self:getPercent()

	local value = percent * 360
	
	local rightMaskRotation = math.clamp(value - 180, -180, 0)
	local leftMaskRotation = self._leftMask.Rotation
	local leftMaskVisible = false

	if value > 180 then
		leftMaskRotation = math.clamp(value - 360, -180, 0)
		leftMaskVisible = true
	end
	self._leftMask.Visible = leftMaskVisible
	
	self._rightMask.Rotation = rightMaskRotation
	self._leftMask.Rotation = leftMaskRotation

	--TweenService:Create(self._rightMask, TweenInfo, {Rotation = rightMaskRotation}):Play()
	--TweenService:Create(self._leftMask, TweenInfo, {Rotation = leftMaskRotation}):Play()
end


function RoundProgressBar.setEnabled(self: ClassType, isEnabled: boolean)
	self._isEnabled = isEnabled
	if self._isEnabled then
		self:_listen()
	else
		self:_disConnect()
	end
end


function RoundProgressBar._listen(self: ClassType)
	self._connect = RunService.Heartbeat:Connect(function()
		local elapsed = os.clock() - self._lastUpdate
		if elapsed < UPDATE_INTERVAL_SECONDS then
			return
		end
		self._lastUpdate = os.clock()
		self:_update()
	end)
end

function RoundProgressBar._disConnect(self: ClassType)
	if self._connect then
		self._connect:Disconnect()
	end
end


function RoundProgressBar.destroy(self: ClassType)
	self:_disConnect()
	self._instance:Destroy()
end

return RoundProgressBar
