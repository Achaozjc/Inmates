--!strict

--[[
	Experience Event 奖励服务端（移植自 dingdong RewardsManager.getEventRewards）。
	客户端关注活动后 invoke GetEventRewards，写入 EventReward 并发放 EventConfig.rewards。
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Network = require(ReplicatedStorage.ReplicatedCode.Framework.Core.Network)
local PlayerDataServer = require(ServerScriptService.ServerCode.Framework.DataStore.PlayerData.PlayerDataServer)
local PlayerService = require(ServerScriptService.ServerCode.GameLogic.Service.Sync.PlayerService)
local EventConfig = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Configs.EventConfig)
local RemoteFunctionKey = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.RemoteFunctionKey)
local PlayerDataKey = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.PlayerDataKey)
local TransactionEnum = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Enums.TransactionEnum)

local EventService = {}

local function ensureTable(value: any): { [any]: any }
	return if type(value) == "table" then value else {}
end

local function getEventRewards(player: Player, eventId: any): (boolean, string?)
	if not PlayerDataServer.hasLoaded(player) then
		return false, "Please wait"
	end

	if typeof(eventId) ~= "string" or eventId == "" then
		return false, "Invalid event"
	end

	local axeData = PlayerDataServer.getValue(player, PlayerDataKey.AxeTycoon)
	local ownedAxeCount = if type(axeData) == "table" then (tonumber(axeData.ownedAxeCount) or 0) else 0
	local rewards = EventConfig.buildRewardEntries(ownedAxeCount)

	local data = ensureTable(PlayerDataServer.getValue(player, PlayerDataKey.EventReward))
	if data[eventId] then
		return false, "Already claimed"
	end

	data[eventId] = true
	PlayerDataServer.setValue(player, PlayerDataKey.EventReward, data)
	PlayerService.getRewards(player, rewards, TransactionEnum.TimedReward, "event_" .. eventId)

	return true, "Reward claimed!"
end

function EventService.listen()
	Network.bindFunction(RemoteFunctionKey.GetEventRewards, getEventRewards, Network.t.string)
end

return EventService
