local ContentProvider = game:GetService("ContentProvider")
local AnimationClipProvider = game:GetService("AnimationClipProvider")

local creatAnimation = {}

local Folder = script:FindFirstChild("Animations")

local assetPrefix = "rbxassetid://"

creatAnimation.animations = {}
creatAnimation.animationMarker = {}

local function getKeyframeSequence(animationId)
	local success, keyframeSequence = pcall(function()
		return AnimationClipProvider:GetAnimationClipAsync(assetPrefix..animationId)
	end)

	if not success then
		warn("Failed to load KeyframeSequence for animation: " .. animationId)
		return nil
	end

	return keyframeSequence
end

local function preload(anim) 
	task.spawn(function()
		ContentProvider:PreloadAsync({anim})
	end)
end


function creatAnimation.create(animationId)  :Animation
	if creatAnimation.animations[animationId] then
		return creatAnimation.animations[animationId]
	else
		local anim = Instance.new("Animation")
		anim.AnimationId = assetPrefix..animationId
		anim.Name = animationId
		anim.Parent = Folder
		creatAnimation.animations[animationId] = anim
		preload(anim) 
		return anim
	end	
end


function creatAnimation.getMarkersCount(animationId) : number
	local marker = creatAnimation.animationMarker[animationId]
	if marker and marker > 0 then
		return creatAnimation.animationMarker[animationId]
	end
	-- 提取KeyframeSequence中的所有标记
	local keyframeSequence = getKeyframeSequence(animationId)
	if not keyframeSequence then
		return 1
	end
	
	local count = 0
	-- 遍历所有关键帧
	for _, keyframe in ipairs(keyframeSequence:GetChildren()) do
		
		if keyframe:IsA("Keyframe") then
			-- 遍历关键帧中的所有标记
			for _, marker in ipairs(keyframe:GetMarkers()) do
				if marker:IsA("KeyframeMarker") then
					count += 1
					---- 将标记信息收集起来
					--table.insert(markers, {
					--	Name = marker.Name,
					--	Time = keyframe.Time
					--})
				end
			end
		end
	end
	creatAnimation.animationMarker[animationId] = count
	return count > 0 and count or 1
end

return creatAnimation
