--!strict


local function getStringSplit(str :string, separator : string)
	local strings = {}
	local split = string.split(str, separator)
	for key,value in split do
		local id = value
		table.insert(strings, id) 
	end
	return strings
end

return getStringSplit