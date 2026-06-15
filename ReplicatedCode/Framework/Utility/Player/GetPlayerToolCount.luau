local function getPlayerToolCount(player: Player, character: Model, backpack: Backpack)
	local count = 0
	for _, tool in character:GetChildren() do
		if tool:IsA("Tool") then
			count += 1
		end
	end
	for _, tool in backpack:GetChildren() do
		if tool:IsA("Tool") then
			count += 1
		end
	end
	return count
end

return getPlayerToolCount