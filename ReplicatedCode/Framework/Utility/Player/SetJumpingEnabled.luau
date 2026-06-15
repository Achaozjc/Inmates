local function setJumpingEnabled(character: Model, enabled: boolean)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	assert(humanoid, "No humanoid found!")
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, enabled)
end

return setJumpingEnabled
