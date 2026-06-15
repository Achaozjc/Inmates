local function SetNetworkOwner(model: Model)
	if not model then warn("Cannot SetNetworkOwner on nil model") return end
	if model:IsDescendantOf(game.Workspace) then
		for _, part in pairs(model:GetDescendants()) do
			if part:IsA("BasePart") then
				part:SetNetworkOwnershipAuto()
			end
		end
	end
end

return SetNetworkOwner
