local function handleHumanoid(humanoid: Humanoid, keepStates: {[Enum.HumanoidStateType]: boolean}?)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)

	-- 按需恢复特定状态（如客人需要 Seated/Jumping）
	if keepStates then
		for state, enabled in keepStates do
			humanoid:SetStateEnabled(state, enabled)
		end
	end

	humanoid.BreakJointsOnDeath = false
	humanoid.AutoJumpEnabled = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
end

return handleHumanoid
