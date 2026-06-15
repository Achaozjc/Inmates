



local function IsInGroup(player: Player, groupId: number)
	local success, isIn = pcall(function()
		return player:IsInGroup(groupId)
	end)
	if success then
		return isIn
	end
	return false
end
return IsInGroup
