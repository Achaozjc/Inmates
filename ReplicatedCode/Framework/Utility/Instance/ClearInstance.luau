local CollectionService = game:GetService("CollectionService")

function clearInstance(instance :Instance)
	local tags = CollectionService:GetTags(instance)

	for _, tag in ipairs(tags) do
		CollectionService:RemoveTag(instance, tag)
	end

	for name, _ in pairs(instance:GetAttributes()) do
		instance:SetAttribute(name, nil)
	end
	
	-- 与 DescendantsCollisionGroup 配合：入池复用时若未先 destroy 组件，部件上会残留 OriginalCollisionGroup，
	-- 导致下次绑定不再设置碰撞组。这里一并清掉，保证复用后能重新被设为目标组。
	local ATTR_ORIGINAL_CG = "OriginalCollisionGroup"
	for _, part in ipairs(instance:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CollisionGroup = "Default"
			part:SetAttribute(ATTR_ORIGINAL_CG, nil)
		end
	end
end

return clearInstance
