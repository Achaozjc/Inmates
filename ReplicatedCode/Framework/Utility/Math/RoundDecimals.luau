--!strict

--[[
	保留几位小数,默认两位
--]]

local function roundDecimals(number :number, numDecimalPlaces : number?)
	local mult = 10 ^ (numDecimalPlaces or 2)
	return math.floor(number * mult + 0.5) / mult
end

return roundDecimals
