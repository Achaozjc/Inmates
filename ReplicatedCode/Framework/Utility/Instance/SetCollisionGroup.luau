


local function setCollisionGroup(model: Model, collisionGroup: string)
	if not model then warn("Cannot setCollisionGroup on nil model") return end
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CollisionGroup = collisionGroup
		end
	end
end

return setCollisionGroup
