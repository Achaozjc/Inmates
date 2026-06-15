local rng = Random.new()

local function RandomInRange(range: number)
	return rng:NextNumber(-range / 2, range / 2)
end

local function GetNumber(inst: Instance, name: string)
	local total: number = 0
	local nextInst: Instance? = inst
	while nextInst do
		total += nextInst:GetAttribute(name) or 0
		nextInst = nextInst.Parent
	end
	return total
end

local SoundRandomizer = {}

function SoundRandomizer.MakeOneshot(sound: Sound) -- pass in a prototype sound to be cloned
	local pitchJitter: number = GetNumber(sound, "PitchJitter")
	local volumeJitter: number = GetNumber(sound, "VolumeJitter")

	local clone = sound:Clone()
	--clone.Ended:Connect(function()
	--	clone:Destroy()
	--end)
	clone.Looped = false
	clone.PlaybackSpeed = sound.PlaybackSpeed + RandomInRange(pitchJitter)
	clone.Volume = sound.Volume + RandomInRange(volumeJitter)
	clone.Parent = workspace

	return clone
end

function SoundRandomizer.randomPitchShot(sound: Sound) -- pass in a prototype sound to be cloned
	local pitchJitter: number = GetNumber(sound, "PitchJitter")
	local volumeJitter: number = GetNumber(sound, "VolumeJitter")

	sound.PlaybackSpeed = 1 + RandomInRange(pitchJitter)
	sound.Volume = 0.5 + RandomInRange(volumeJitter)
end

return SoundRandomizer
