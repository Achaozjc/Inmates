local jumpingEnums = {
	Enum.HumanoidStateType.Freefall,
	Enum.HumanoidStateType.Jumping,
	Enum.HumanoidStateType.Landed,
}

local function isJumping(humanoid: Humanoid): boolean
	if not humanoid then
		return false
	end

	local invalidState = table.find(jumpingEnums, humanoid:GetState()) ~= nil
	local invalidFloor = humanoid.FloorMaterial == Enum.Material.Air

	return invalidState or invalidFloor
end

return isJumping
