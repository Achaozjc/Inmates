local function SetNetworkOwner(model: Model, owner :Player?)
	if not model then
		warn("Cannot SetNetworkOwner on nil model")
		return
	end
	if model:IsDescendantOf(game.Workspace) then
		for _, part in pairs(model:GetDescendants()) do
			if part:IsA("BasePart") then
				-- 先做可设置性检查：锚固件或焊到锚固件会返回 false，避免直接抛错打断主循环
				local canSet, reason = part:CanSetNetworkOwnership()
				if canSet then
					part:SetNetworkOwner(owner or nil)
				else
					warn(
						string.format(
							"[SetNetworkOwner] skip part=%s model=%s reason=%s",
							part:GetFullName(),
							model:GetFullName(),
							tostring(reason)
						)
					)
				end
			end
		end
	end
end

return SetNetworkOwner
