

local function resetHumanoidDescription(humanoid: Humanoid)
	local descriptionClone = humanoid:GetAppliedDescription() ::HumanoidDescription
	descriptionClone.Torso = 0
	descriptionClone.LeftArm = 0
	descriptionClone.LeftLeg = 0
	descriptionClone.RightArm = 0
	descriptionClone.RightLeg = 0

	descriptionClone.HeadScale = 1
	descriptionClone.DepthScale = 1
	descriptionClone.WidthScale = 1
	descriptionClone.HeightScale = 1
	descriptionClone.BodyTypeScale = 0

	humanoid:ApplyDescriptionAsync(descriptionClone, Enum.AssetTypeVerification.Default)	
end

return resetHumanoidDescription