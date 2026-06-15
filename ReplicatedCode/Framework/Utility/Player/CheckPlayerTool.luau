local ReplicatedStorage = game:GetService("ReplicatedStorage")



local function checkPlayerTool(player: Player, theTool: Tool)

	-- 获取玩家的 Character
	local character: Model? = player.Character
	-- 有时 Character 可能为 nil，尝试获取最近的
	if not character or not character.Parent then
		-- 尝试通过 Player 的 Joins/已存在的 Character 重新获取
		character = player.Character
	end

	-- 获取玩家的 Backpack
	local backpack: Folder? = player:FindFirstChild("Backpack")

	-- 优先：Tool 在玩家的 Character 下
	if character and theTool:IsDescendantOf(character) then
		return true
	end

	-- 次：Tool 在 Backpack 下
	if backpack and theTool:IsDescendantOf(backpack) then
		return true
	end

	return false
end

return checkPlayerTool