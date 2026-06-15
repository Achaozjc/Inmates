local function getPlayerAllTools(character: Model?, backpack: Backpack)
	local tools = {}
	if character then
		for _, tool in character:GetChildren() do
			if tool:IsA("Tool") then
				if table.find(tools, tool) then
					continue
				end
				table.insert(tools, tool)
			end
		end
	end
	if backpack then
		for _, tool in backpack:GetChildren() do
			if tool:IsA("Tool") then
				if table.find(tools, tool) then
					continue
				end
				table.insert(tools, tool)
			end
		end
	end

	return tools
end

return getPlayerAllTools