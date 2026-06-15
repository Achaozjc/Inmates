--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Network = require(ReplicatedStorage.ReplicatedCode.Framework.Core.Network)
local PlayerDataServer = require(ServerScriptService.ServerCode.Framework.DataStore.PlayerData.PlayerDataServer)

local PlayerDataKey = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.PlayerDataKey)
local RemoteFunctionKey = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.RemoteFunctionKey)
local RemoteKey = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.RemoteKey)
local RewardEnum = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Enums.RewardEnum)
local TransactionEnum = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Enums.TransactionEnum)

local PlayerService = require(ServerScriptService.ServerCode.GameLogic.Service.Sync.PlayerService)

local RewardService = {}

local function ensureTable(value: any): { [any]: any }
	return if type(value) == "table" then value else {}
end

function RewardService.getRewards(player: Player, rewards: { any }, transactionType: string?)
	PlayerService.getRewards(player, rewards, transactionType or TransactionEnum.TimedReward)
end

local function claimSign(player: Player): (boolean, string)
	local dateData = ensureTable(PlayerDataServer.getValue(player, PlayerDataKey.Date))
	local sign = ensureTable(dateData.sign)
	if sign.claim == true then
		return false, "Already claimed."
	end

	local signLoop = RewardEnum.getSignLoopIndex(sign.loop)
	local rewardList = RewardEnum.getSignRewardsByLoop(signLoop)
	local nextIndex = (tonumber(sign.index) or 0) + 1
	if nextIndex > #rewardList then
		nextIndex = 1
		signLoop += 1
	end

	local rewards = rewardList[nextIndex]
	if type(rewards) ~= "table" then
		return false, "Reward is not configured."
	end

	PlayerService.getRewards(player, rewards, TransactionEnum.TimedReward, "sign")

	PlayerDataServer.updateValue(player, PlayerDataKey.Date, function(currentDate)
		currentDate = ensureTable(currentDate)
		currentDate.sign = ensureTable(currentDate.sign)
		currentDate.sign.index = nextIndex
		currentDate.sign.loop = signLoop
		currentDate.sign.claim = true
		return currentDate
	end)

	return true, "Reward claimed."
end

local function claimOnline(player: Player): (boolean, string)
	local dateData = ensureTable(PlayerDataServer.getValue(player, PlayerDataKey.Date))
	local online = ensureTable(dateData.online)
	local minutes = tonumber(online.minute) or 0
	local claimedIndex = tonumber(online.claimedIndex) or 0
	local nextIndex = claimedIndex + 1
	local entry = RewardEnum.Online[nextIndex]
	if not entry then
		return false, "All rewards claimed."
	end
	if minutes < (tonumber(entry.minutes) or math.huge) then
		return false, "Reward is not ready."
	end

	PlayerService.getRewards(player, entry.rewards or {}, TransactionEnum.TimedReward, "online")

	PlayerDataServer.updateValue(player, PlayerDataKey.Date, function(currentDate)
		currentDate = ensureTable(currentDate)
		currentDate.online = ensureTable(currentDate.online)
		currentDate.online.minute = minutes
		currentDate.online.claimedIndex = nextIndex
		return currentDate
	end)

	return true, "Reward claimed."
end

local function claimReward(player: Player, rewardKey: string): (boolean, string)
	if rewardKey == RemoteKey.Sign then
		return claimSign(player)
	elseif rewardKey == RemoteKey.Online then
		return claimOnline(player)
	end
	return false, "Reward is not configured."
end

function RewardService.listen()
	Network.bindFunction(RemoteFunctionKey.ClaimReward, function(player, rewardKey)
		return claimReward(player, rewardKey)
	end, Network.t.tuple(Network.t.string))
end

function RewardService.start()
end

return RewardService
