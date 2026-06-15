local ReplicatedStorage = game:GetService("ReplicatedStorage")

local playSoundFromSource = require(ReplicatedStorage.ReplicatedCode.GameLogic.Gameplay.playSoundFromSource)

local random = Random.new()

local function playRandomSoundFromSource(soundTemplates: Folder, target: Instance)
	local sounds = soundTemplates:GetChildren()
	local sound = sounds[random:NextInteger(1, #sounds)]
	playSoundFromSource(sound, target)
end

return playRandomSoundFromSource
