
local COOLDOWN_TIME = 1  -- cooldown time in seconds
local ATTRIBUTE = "lastRequestTime"

local function eazyCooldown(player: Player | any, cooldown: number?, attribute: string?)
	local attributeName = attribute or ATTRIBUTE
	local coolDown = cooldown or COOLDOWN_TIME
	local lastRequestTime = player:GetAttribute(attributeName) or 0
	local currentTime = os.time()
	if currentTime - lastRequestTime < coolDown then
		return false
	end
	player:SetAttribute(attributeName, currentTime)
	return true
end


return eazyCooldown
