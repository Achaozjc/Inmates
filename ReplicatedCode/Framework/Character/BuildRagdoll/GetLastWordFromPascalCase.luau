--[[
	Returns the last word in a PascalCase string, ignoring any trailing numbers. E.g.
	
	LeftUpperArm -> Arm
	LeftElbow -> Elbow
	LeftUpperLeg4 -> Leg
	TestT3st4 -> T3st
	test -> test (whole string returned if there are no uppercase characters)
	3 -> ""
--]]

return function (str: string): string
	-- Get the last word in the PascalCase name (e.g. Arm from UpperLeftArm)
	local reversed = str:reverse()
	local index = reversed:find("%u")
	if not index then
		index = #str + 1
	end
	
	local lastWord = str:sub(#str - (index - 1))
	-- Remove trailing numbers from the name
	lastWord = lastWord:gsub("%d+$", "")
	
	return lastWord
end
