
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local _RANDOM = Random.new()
local UD2Scale = UDim2.fromScale
local Signal = require(ReplicatedStorage.ReplicatedCode.Framework.Packages.Signal)


local OffsetConvert = 700


local GuiShake = {}
GuiShake.__index = GuiShake

export type ClassType = typeof(setmetatable(
	{} :: {
		_instance: GuiButton,
		_connect: RBXScriptConnection?,
		_isShaking: boolean,
		_shakeEnd: Signal.ClassType,
		
		_originalPosition: UDim2,
		_originalRotation: number
	},
	GuiShake
	))


function GuiShake.new(instance: GuiObject): ClassType
	local self = {}	
	setmetatable(self, GuiShake)

	self._instance = instance
	
	self._connect = nil

	self._originalPosition = self._instance.Position
	self._originalRotation = self._instance.Rotation
	
	self._isShaking = false
	self._shakeEnd = Signal.new()
	
	return self 
end



function GuiShake._shakeOnce(self: ClassType,  intensity :number, fadeOutTime :number)	
	if self._isShaking then
		return
	end
	self._isShaking = true
	local t = os.clock()
	self._connect = RunService.Heartbeat:Connect(function(dt)
		if os.clock() - t <= fadeOutTime then
			self._instance.Position = self._originalPosition + UD2Scale(
				_RANDOM:NextNumber(-intensity, intensity)/OffsetConvert,
				_RANDOM:NextNumber(-intensity, intensity)/OffsetConvert
			)
			self._instance.Rotation = _RANDOM:NextNumber(-intensity, intensity) / 2
		else
			self:_reset()
			self._shakeEnd:Fire()
		end
	end)
	
	
end

function GuiShake._reset(self: ClassType)
	if self._connect then
		self._connect:Disconnect()
		self._connect = nil
	end
	self._isShaking = false
	self._instance.Position = self._originalPosition
	self._instance.Rotation = self._originalRotation
end


function GuiShake.destroy(self: ClassType)
	if self._connect then
		self._connect:Disconnect()
		self._connect = nil
	end
	self._shakeEnd:DisconnectAll()
end



return GuiShake


