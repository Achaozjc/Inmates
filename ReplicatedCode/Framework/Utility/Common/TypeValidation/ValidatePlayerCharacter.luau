local function validatePlayrCharacter(player: Player): Model | boolean
	local character = player.Character
	if not character then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end
	if humanoid.Health <= 0 then
		return false
	end
	local primaryPart = character.PrimaryPart
	if not primaryPart then
		return false
	end
	return character
end

return validatePlayrCharacter
