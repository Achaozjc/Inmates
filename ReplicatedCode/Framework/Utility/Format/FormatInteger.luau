--!strict

local RULE = [[^(-?%d+)(%d%d%d)]]

function formatInteger(amount: any)
	amount = math.floor(amount + 0.5)
	local formatted = amount
	local numMatches
	repeat
		formatted, numMatches = string.gsub(formatted, RULE, "%1,%2")
	until numMatches == 0
	return formatted
end

return formatInteger
