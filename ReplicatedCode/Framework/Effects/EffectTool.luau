local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local DebrisFolder = game.Workspace:WaitForChild("DebrisFolder")
local TweenService = game:GetService("TweenService")


local lightInfo = TweenInfo.new(.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local lightGoal = {Brightness = 0}
local weldParts = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Instance.WeldParts)
local tweenInfo_dis = TweenInfo.new(1,Enum.EasingStyle.Linear,Enum.EasingDirection.Out,0,false,1)

local EffectFolder = DebrisFolder:WaitForChild("EffectFolder")

local EffectTool = {}


local function checkEffect(effects)
	if typeof(effects) == "table" then
		return effects
	else
		return effects:GetDescendants()
	end
end


function EffectTool._creatOnce(prefab: Instance , cframe: CFrame, attachTo: BasePart?, color: ColorSequence?)
	local effect = prefab:Clone()
	effect.CFrame = if attachTo then attachTo.CFrame * cframe else cframe
	if color then
		EffectTool._setColor(effect, color)
	end
	effect.Parent = DebrisFolder
	if attachTo then
		weldParts(attachTo, effect)
	end
	EffectTool._emit(effect)
	Debris:AddItem(effect, 2)
end


function EffectTool._emit(effects: Instance | {ParticleEmitter}, count :number?, enabled :boolean?)
	for _ ,effect in pairs(checkEffect(effects)) do
		if effect:IsA("ParticleEmitter") then
			effect:Emit(count or effect:GetAttribute("EmitCount") or 5)
			effect.Enabled = enabled
		elseif effect:IsA("Light") then
			effect.Brightness = 10
			TweenService:Create(effect, lightInfo, lightGoal):Play()
		end		
	end
end

function EffectTool._setEnabled(effects, enabled :boolean)
	for _ ,effect in pairs(checkEffect(effects)) do
		if effect:IsA("ParticleEmitter") then
			effect.Enabled = enabled
		end

	end
end

function EffectTool._setColor(effects, color :ColorSequence)
	for _ ,effect in pairs(checkEffect(effects)) do
		if effect:IsA("ParticleEmitter") then
			effect.Color = color
		end	
	end
end

function EffectTool._setScale(effects, size :number, emit :boolean?)
	for _ ,effect in pairs(checkEffect(effects)) do
		local currentSize = effect.Size
		local newSizeKeypoints = {}	-- 创建新的粒子大小

		for i, keypoint in ipairs(currentSize.Keypoints) do
			local scaledValue = keypoint.Value * size
			table.insert(newSizeKeypoints, NumberSequenceKeypoint.new(keypoint.Time, scaledValue , keypoint.Envelope))
		end

		local newSize = NumberSequence.new(newSizeKeypoints)			
		effect.Size = newSize  -- 将粒子大小设置为新的大小

		if emit then
			EffectTool._emit(effects)
		end	
	end
end





return EffectTool

