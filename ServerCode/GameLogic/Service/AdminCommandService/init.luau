--!strict
-- 管理员聊天命令 Service：由 Loader 加载，start 时初始化 TextChatCommand

local TextChatService = game:GetService("TextChatService")

local AdminCommands = require(script.AdminCommands)

local AdminCommandService = {}

function AdminCommandService.start()
	assert(
		TextChatService.ChatVersion == Enum.ChatVersion.TextChatService,
		"TextChatService.ChatVersion must be set to 'TextChatService'"
	)
	AdminCommands._initialize()
end

function AdminCommandService.listen()
	-- 无异步监听逻辑，留空
end

return AdminCommandService
