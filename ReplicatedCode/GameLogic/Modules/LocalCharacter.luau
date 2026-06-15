local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local localplayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() :: Player

local CharacterLoadedWrapper = require(ReplicatedStorage.ReplicatedCode.Framework.Character.CharacterLoadedWrapper)
local Signal = require(ReplicatedStorage.ReplicatedCode.Framework.Packages.Signal)

export type ClassType = {
	playerGui: PlayerGui,
	player: Player,
	character: Model?,
	rootPart: BasePart?,
	humanoid: Humanoid?,
	primaryPart: BasePart?,
	rightGripAttachment: Attachment?,
	lastHealth: number?,
	characterLoadedWrapper: CharacterLoadedWrapper.ClassType,
	added: Signal.ClassType,
	_started: boolean?,
	_onCharacterAdded: (Model) -> (),
	_getState: () -> Enum.HumanoidStateType,
	_onDead: () -> (),
	_isAlive: () -> boolean,
	init: () -> (),
	start: () -> (),
	getPosition: () -> Vector3,
}

local LocalCharacter = {
	playerGui = localplayer:WaitForChild("PlayerGui") :: PlayerGui,
	characterLoadedWrapper = CharacterLoadedWrapper.new(localplayer),

	player = localplayer,
	character = nil,
	rootPart = nil,
	humanoid = nil,
	added = Signal.new(),
}

function LocalCharacter._onCharacterAdded(newCharacter: Model)
	if LocalCharacter.character == newCharacter then
		return
	end
	LocalCharacter.character = newCharacter
	LocalCharacter.rootPart = newCharacter:WaitForChild(`HumanoidRootPart`) :: BasePart
	local humanoid = newCharacter:WaitForChild(`Humanoid`) :: Humanoid
	LocalCharacter.humanoid = humanoid
	LocalCharacter.lastHealth = humanoid.Health

	LocalCharacter.primaryPart = newCharacter.PrimaryPart

	LocalCharacter.added:Fire(newCharacter)
end

function LocalCharacter._getState()
	local h = LocalCharacter.humanoid
	assert(h, "LocalCharacter._getState: humanoid 未就绪")
	return h:GetState()
end

function LocalCharacter.getPosition()
	if not LocalCharacter.rootPart or not LocalCharacter.rootPart.Parent then return Vector3.zero end
	return LocalCharacter.rootPart.Position
end


function LocalCharacter._isAlive()
	if not LocalCharacter.character or not LocalCharacter.character:IsDescendantOf(workspace) then
		return false
	end
	if not LocalCharacter.humanoid then
		return false
	end
	return LocalCharacter.humanoid.Health > 0 and LocalCharacter.humanoid:GetState() ~= Enum.HumanoidStateType.Dead
end

function LocalCharacter._onDead()
	LocalCharacter.added:Fire()
end

function LocalCharacter.init()
	LocalCharacter.characterLoadedWrapper.loaded:Connect(function(character: any)
		LocalCharacter._onCharacterAdded(character)
	end)

	if LocalCharacter.characterLoadedWrapper:isLoaded() then
		LocalCharacter._onCharacterAdded(localplayer.Character)
	end

	LocalCharacter.characterLoadedWrapper.died:Connect(function()
		LocalCharacter._onDead()
	end)
end

function LocalCharacter.start()
	assert(not LocalCharacter._started, "LocalCharacter started more than once")
	LocalCharacter._started = true
	LocalCharacter.init()
end

return LocalCharacter
