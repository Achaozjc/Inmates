local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AttributeEnum = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Enums.AttributeEnum)

local function playSoundFromSource(playerTemplate: AudioPlayer, target: Instance, volume: number?)
    local audioPlayer = playerTemplate:Clone()
    audioPlayer.Parent = target

    local wire = audioPlayer:WaitForChild("Wire") :: Wire
    if wire then
        wire.TargetInstance = target
    else
        audioPlayer:Destroy()
        return
    end

    -- local wire = Instance.new("Wire")
    -- wire.SourceInstance = audioPlayer
    -- wire.TargetInstance = target
    -- wire.Parent = audioPlayer
    audioPlayer.Volume = volume or (ReplicatedStorage:GetAttribute(AttributeEnum.Setting.world) or 0.5) :: number
    audioPlayer:Play()
    audioPlayer.Ended:Once(function()
        audioPlayer:Destroy()
    end)
end

return playSoundFromSource
