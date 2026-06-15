--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Network = require(ReplicatedStorage.ReplicatedCode.Framework.Core.Network)
local RemoteEventKey = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.RemoteEventKey)
local AttributeEnum = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Enums.AttributeEnum)
local ChannelCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.ChannelCategory)

local localPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait()

local ChatController = {
	Name = "ChatController",
	channels = {} :: { [string]: TextChannel },
	_started = false,
	_listening = false,
}

local VIP_PREFIX_TEXT = "[VIP]"
local VIP_PREFIX_COLOR = "#FFC735"

local function waitForChannel(channelName: string): TextChannel?
	local textChannels = TextChatService:WaitForChild("TextChannels")
	local channel = TextChatService:FindFirstChild(channelName) or textChannels:FindFirstChild(channelName)
	if channel and channel:IsA("TextChannel") then
		return channel
	end

	local waited = textChannels:WaitForChild(channelName, 10)
	if waited and waited:IsA("TextChannel") then
		return waited
	end

	return nil
end

function ChatController:systemMessage(channelName: string, message: string)
	local channel = self.channels[channelName]
	if channel then
		channel:DisplaySystemMessage(message)
	else
		warn(`[ChatController] Channel not found: {channelName}`)
	end
end

function ChatController:listen()
	if self._listening then
		return
	end
	self._listening = true

	Network.connectEvent(RemoteEventKey.Unreliable_ServerChatMessage, function(channelName, _messagePrefix, messageData)
		local message = if typeof(messageData) == "string" then messageData else tostring(messageData)
		self:systemMessage(channelName, message)
	end, Network.t.tuple(Network.t.string, Network.t.string, Network.t.any))

	TextChatService.OnChatWindowAdded = function(textChatMessage: TextChatMessage)
		local properties = TextChatService.ChatWindowConfiguration:DeriveNewMessageProperties()
		if not textChatMessage.TextSource then
			return properties
		end

		local player = Players:GetPlayerByUserId(textChatMessage.TextSource.UserId)
		if player and player:GetAttribute(AttributeEnum.Player.vip) then
			properties.PrefixText = string.format(
				[[<font color="%s">%s</font> %s]],
				VIP_PREFIX_COLOR,
				VIP_PREFIX_TEXT,
				textChatMessage.PrefixText
			)
		end

		return properties
	end
end

function ChatController:start()
	if self._started then
		return
	end
	self._started = true

	local generalChannel = waitForChannel(ChannelCategory.RBXGeneral)
	if generalChannel then
		self.channels[ChannelCategory.RBXGeneral] = generalChannel
	end

	TextChatService.ChatWindowConfiguration.Enabled = true
	TextChatService.ChatInputBarConfiguration.Enabled = true
end

function ChatController:init()
	self:start()
	self:listen()
end

return ChatController
