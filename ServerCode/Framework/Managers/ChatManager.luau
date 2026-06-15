--!strict

local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TextChatService = game:GetService("TextChatService")

local Network = require(ReplicatedStorage.ReplicatedCode.Framework.Core.Network)
local PlayerDataServer = require(ServerScriptService.ServerCode.Framework.DataStore.PlayerData.PlayerDataServer)
local RemoteEventName = require(ReplicatedStorage.ReplicatedCode.Framework.Core.Network.RemoteName.RemoteEventName)
local AttributeEnum = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Enums.AttributeEnum)
local ChannelCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.ChannelCategory)
local RichTextCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.RichTextCategory)

local topic = "GlobalAnnouncements"
local jobId = game.JobId

local ChatManager = {}
ChatManager.channels = {} :: { [ChannelCategory.EnumType]: TextChannel }

local function filterSystem(player: Player): boolean
	if not PlayerDataServer.hasLoaded(player) then
		return true
	end
	return player:GetAttribute(AttributeEnum.Setting.serverNotify) == false
end

local function filterGlobal(player: Player): boolean
	if not PlayerDataServer.hasLoaded(player) then
		return true
	end
	return player:GetAttribute(AttributeEnum.Setting.globalNotify) == false
end

local function getDefaultChannel(): TextChannel?
	local textChannels = TextChatService:WaitForChild("TextChannels")
	local channel = textChannels:WaitForChild(ChannelCategory.RBXGeneral, 10)
	if not channel or not channel:IsA("TextChannel") then
		warn("[ChatManager] RBXGeneral channel not found.")
		return nil
	end
	return channel
end

function ChatManager.addChannel(_player: Player)
end

function ChatManager.publishMessage(data: any)
	data.jobId = jobId
	local message = data.message or data.text or tostring(data)

	MessagingService:PublishAsync(topic, data)
	Network.fireClientsFilter(
		RemoteEventName.Unreliable_ServerChatMessage,
		filterSystem,
		ChannelCategory.RBXGeneral,
		RichTextCategory.messagePrefix.system,
		message
	)
end

function ChatManager.start()
	task.spawn(function()
		MessagingService:SubscribeAsync(topic, function(message)
			if message.Data.jobId == jobId then
				return
			end

			local text = message.Data.message or message.Data.text or tostring(message.Data)
			Network.fireClientsFilter(
				RemoteEventName.Unreliable_ServerChatMessage,
				filterGlobal,
				ChannelCategory.RBXGeneral,
				RichTextCategory.messagePrefix.global,
				text
			)
		end)
	end)

	local channel = getDefaultChannel()
	if channel then
		ChatManager.channels[ChannelCategory.RBXGeneral] = channel
	end

	for _, player in ipairs(Players:GetPlayers()) do
		ChatManager.addChannel(player)
	end
	Players.PlayerAdded:Connect(ChatManager.addChannel)
end

return ChatManager
