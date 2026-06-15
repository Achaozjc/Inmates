--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local AttributeEnum = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Enums.AttributeEnum)
local getCodeAsset = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Instance.GetCodeAsset)
local AudioPrefab = getCodeAsset("Components", "Audio") :: Folder

local ENGINE_VOLUME_STARTUP_TWEEN_TIME = 0.3
local ENGINE_PLAYBACK_SPEED_FACTOR = 1 / 80

local Audio = {}
Audio.__index = Audio

export type ClassType = typeof(setmetatable({} :: {
	_instance: Model,
	_base: BasePart,
	_seat: VehicleSeat?,
	_driveEngine: Folder?,
	_engineFolder: Folder?,
	_engineLoop: AudioPlayer?,
	_engineStartup: AudioPlayer?,
	_engineShutdown: AudioPlayer?,
	_heartbeatConnection: RBXScriptConnection?,
	_engineRunning: boolean,
	_engineVolume: number,
	_enginePlaybackSpeed: number,
}, Audio))

local function findAudioPlayer(parent: Instance, playerName: string): AudioPlayer?
	local direct = parent:FindFirstChild(playerName)
	if direct and direct:IsA("AudioPlayer") then
		return direct
	end
	local nested = parent:FindFirstChild(playerName, true)
	if nested and nested:IsA("AudioPlayer") then
		return nested
	end
	return nil
end

local function resolveAudioEngineFolder(emitter: Instance): Folder?
	local audioFolder = emitter:FindFirstChild("Audio")
	if audioFolder and audioFolder:IsA("Folder") then
		local players = audioFolder:FindFirstChild("Players")
		local engine = players and players:FindFirstChild("Engine")
		if engine and engine:IsA("Folder") then
			return engine
		end
	end

	local compatEngine = emitter:FindFirstChild("Engine")
	if compatEngine and compatEngine:IsA("Folder") then
		return compatEngine
	end

	local audioClone = AudioPrefab:Clone()
	audioClone.Name = "Audio"
	audioClone.Parent = emitter
	for _, wire in ipairs(audioClone:GetDescendants()) do
		if wire:IsA("Wire") and wire.Name == "OutputWire" then
			wire.TargetInstance = emitter :: any
		end
	end

	local players = audioClone:FindFirstChild("Players")
	local engine = players and players:FindFirstChild("Engine")
	if engine and engine:IsA("Folder") then
		return engine
	end
	return nil
end

function Audio.new(instance: Model): ClassType
	local self = {
		_instance = instance,
		_base = instance:WaitForChild("RootPart") :: BasePart,
		_seat = instance:FindFirstChildWhichIsA("VehicleSeat"),
		_driveEngine = instance:FindFirstChild("Engine") :: Folder?,
		_engineFolder = nil,
		_engineLoop = nil,
		_engineStartup = nil,
		_engineShutdown = nil,
		_heartbeatConnection = nil,
		_engineRunning = false,
		_engineVolume = 0,
		_enginePlaybackSpeed = 1,
	}
	setmetatable(self, Audio)

	self:setup()

	return self
end

function Audio.setup(self: ClassType)
	local emitter = self._base:FindFirstChild("AudioEmitter")
	if not emitter then
		return
	end

	local engineFolder = resolveAudioEngineFolder(emitter)
	if not engineFolder or not engineFolder:IsA("Folder") then
		return
	end

	local engineLoop = findAudioPlayer(engineFolder, "EngineLoopPlayer")
	if not engineLoop then
		return
	end

	self._engineFolder = engineFolder
	self._engineLoop = engineLoop
	self._engineStartup = findAudioPlayer(engineFolder, "EngineStartupPlayer")
	self._engineShutdown = findAudioPlayer(engineFolder, "EngineShutdownPlayer")
	self._engineVolume = engineLoop.Volume
	self._enginePlaybackSpeed = engineLoop.PlaybackSpeed

	self._heartbeatConnection = RunService.Heartbeat:Connect(function()
		self:update()
	end)
end

function Audio.startupEngine(self: ClassType)
	if self._engineRunning then
		return
	end
	if not self._engineLoop then
		return
	end

	self._engineRunning = true

	if self._engineStartup then
		self._engineStartup:Play()
	end

	self._engineLoop.Volume = 0
	self._engineLoop:Play()

	local tweenInfo = TweenInfo.new(ENGINE_VOLUME_STARTUP_TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local tween = TweenService:Create(self._engineLoop, tweenInfo, { Volume = self._engineVolume })
	tween:Play()
end

function Audio.shutdownEngine(self: ClassType)
	if not self._engineRunning then
		return
	end
	if not self._engineLoop then
		return
	end

	self._engineRunning = false

	if self._engineShutdown then
		self._engineShutdown:Play()
	end
	self._engineLoop:Stop()
end

function Audio.update(self: ClassType)
	local engineLoop = self._engineLoop
	if not engineLoop then
		return
	end

	local isOccupied = false
	if self._seat and self._seat.Occupant then
		isOccupied = true
	end
	if isOccupied and (not self._engineRunning) then
		self:startupEngine()
	elseif (not isOccupied) and self._engineRunning then
		self:shutdownEngine()
	end

	local engineFolder = self._driveEngine
	local engineSpeed = 0
	if engineFolder then
		engineSpeed = (engineFolder:GetAttribute(AttributeEnum.Speed) or 0) :: number
	end
	local speedAbs = math.abs(engineSpeed)

	local enginePlaybackSpeed = self._enginePlaybackSpeed + speedAbs * ENGINE_PLAYBACK_SPEED_FACTOR
	engineLoop.PlaybackSpeed = enginePlaybackSpeed
end

function Audio.destroy(self: ClassType)
	if self._heartbeatConnection then
		self._heartbeatConnection:Disconnect()
		self._heartbeatConnection = nil
	end
	self:shutdownEngine()
end

return Audio
