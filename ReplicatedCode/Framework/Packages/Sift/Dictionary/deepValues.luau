--!strict
--[=[
  @function values
  @within Dictionary

  @param dictionary {[K]: V} -- The dictionary to get the values from.
  @return {V} -- The values in the dictionary.

  Gets the values in the given dictionary.

  ```lua
  local dictionary = { hello = "roblox", goodbye = "world" }

  local values = Values(dictionary) -- { "roblox", "world" }
  ```
]=]
local function deepValues<K, V>(dictionary: { [K]: V }): { V }
	local result = {}

	for _, value in pairs(dictionary) do
		if typeof(value) == "table" and #value > 0 then
			for _, nestedValue in pairs(value) do
				table.insert(result, nestedValue)
			end
		else
			table.insert(result, value)
		end
	
	end

	return result
end

return deepValues
