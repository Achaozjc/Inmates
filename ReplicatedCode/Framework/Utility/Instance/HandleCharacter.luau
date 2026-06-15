--!strict



local function handleCharacter(character: Model, messless:boolean?)
	for _, child in ipairs(character:GetDescendants()) do
		if child:IsA("Script") or child:IsA("LocalScript") or child:IsA("Sound") then
			child:Destroy()
		end
		if messless and child:IsA("BasePart") then
			child.Massless = true
		end
	end
end


return handleCharacter
