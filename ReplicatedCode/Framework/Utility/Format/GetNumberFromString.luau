local function get_number_from_string(str: string, isNumber: boolean?)
	local numberStr = str:match("_(%d+)")
	if isNumber then
		return tonumber(numberStr)
	else
		return numberStr
	end
end

return get_number_from_string
