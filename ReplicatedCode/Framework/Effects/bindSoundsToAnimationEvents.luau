local playSoundFromSource = require(script.Parent.playSoundFromSource)
local playRandomSoundFromSource = require(script.Parent.playRandomSoundFromSource)

local SOUND_EVENT = "Sound"
local RANDOM_SOUND_EVENT = "RandomSound"

local function bindSoundsToAnimationEvents(animation: AnimationTrack, sounds: Folder, target: Instance)
	animation:GetMarkerReachedSignal(SOUND_EVENT):Connect(function(param: string)
		local sound = sounds:FindFirstChild(param)
		if not sound then
			return
		end
		playSoundFromSource(sound, target)
	end)

	-- For repetitive sounds like shooting, we'll play a random sound variation from a selection, rather than playing the same sound over and over.
	animation:GetMarkerReachedSignal(RANDOM_SOUND_EVENT):Connect(function(param: string)
		local folder = sounds:FindFirstChild(param)
		if not folder then
			return
		end
		playRandomSoundFromSource(folder, target)
	end)
end

return bindSoundsToAnimationEvents
