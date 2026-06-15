--!strict
-- 管理员聊天命令核心：由 AdminCommandService 在 start 时初始化，不自动执行

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local Commands = require(script.Commands)
local Admins = require(script.Admins)

local AdminCommands = {
	_initialized = false,
	_permissionCache = {},
}

function AdminCommands.getPermissionLevelAsync(player: Player): number
	if AdminCommands._permissionCache[player] then
		return AdminCommands._permissionCache[player]
	end

	local permissionLevel = 0
	if Admins.UserIds[player.UserId] then
		permissionLevel = Admins.UserIds[player.UserId]
	else
		permissionLevel = player:GetRankInGroupAsync(Admins.GroupId)
	end

	AdminCommands._permissionCache[player] = permissionLevel
	return permissionLevel
end

function AdminCommands._initialize()
	assert(not AdminCommands._initialized, "Module already initialized")

	Players.PlayerRemoving:Connect(function(player)
		if AdminCommands._permissionCache[player] then
			AdminCommands._permissionCache[player] = nil
		end
	end)

	local commandsFolder = Instance.new("Folder")
	commandsFolder.Name = "AdminCommands"
	commandsFolder.Parent = TextChatService

	for _, commandInfo in Commands.List do
		local textChatCommand = Instance.new("TextChatCommand")
		textChatCommand.Name = commandInfo.PrimaryAlias
		textChatCommand.PrimaryAlias = Commands.Prefix .. commandInfo.PrimaryAlias
		if commandInfo.SecondaryAlias then
			textChatCommand.SecondaryAlias = Commands.Prefix .. commandInfo.SecondaryAlias
		end
		textChatCommand.Parent = commandsFolder

		textChatCommand.Triggered:Connect(function(textSource, message)
			local player = Players:GetPlayerByUserId(textSource.UserId)
			assert(player ~= nil, string.format("No player with UserId: %d", textSource.UserId))

			local playerPermissionLevel = AdminCommands.getPermissionLevelAsync(player)
			if playerPermissionLevel >= commandInfo.PermissionLevel then
				local cleanMessage = string.gsub(message, "%s+", " ")
				local words = string.split(cleanMessage, " ")
				local args = table.move(words, 2, #words, 1, {})
				commandInfo.Function(player, args)
			end
		end)
	end

	AdminCommands._initialized = true
end

return AdminCommands
