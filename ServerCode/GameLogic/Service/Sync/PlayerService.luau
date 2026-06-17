--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Network = require(ReplicatedStorage.ReplicatedCode.Framework.Core.Network)
local PlayerDataServer = require(ServerScriptService.ServerCode.Framework.DataStore.PlayerData.PlayerDataServer)
local AnalyticsManager = require(ServerScriptService.ServerCode.Framework.Managers.AnalyticsManager)
local StatisticManager = require(ServerScriptService.ServerCode.Framework.Managers.StatisticManager)

local AttributeEnum = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Enums.AttributeEnum)
local CashKey = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.CashKey)
local CategoryConfig = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Configs.CategoryConfig)
local PlayerCurrencySpend = require(ServerScriptService.ServerCode.GameLogic.Service.PlayerCurrencySpend)
local PlayerDataKey = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.PlayerDataKey)
local RemoteEventKey = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.RemoteEventKey)
local RemoteFunctionKey = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.RemoteFunctionKey)
local SettingEnum = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Enums.SettingEnum)
local StatisticKeys = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.StatisticKeys)
local StatisticTypeCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.StatisticTypeCategory)
local TimestampCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.TimestampCategory)
local TransactionEnum = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Enums.TransactionEnum)

local PlayerService = {}

type RewardItem = {
	category: string,
	itemKey: string,
	value: number,
}

local friendLuckDebounce: { [Player]: number } = {}
local FRIEND_LUCK_COOLDOWN = 10
-- 每位同服好友 +10% Cash，倍率 clamp 到 [1, 1.5]（移植自 Spicy PlayerBoostServer）
local FRIEND_BOOST_PER_FRIEND = 0.1
local FRIEND_BOOST_MIN = 1
local FRIEND_BOOST_MAX = 1.5
local ONLINE_INCREMENT_SECONDS = 60

local function ensureTable(value: any): { [any]: any }
	return if type(value) == "table" then value else {}
end

local function getSettingInfo(settingKey: string): any?
	for _, group in pairs(SettingEnum) do
		if type(group) == "table" and group[settingKey] then
			return group[settingKey]
		end
	end
	return nil
end

local function getSettingDefault(settingKey: string): any
	local settingInfo = getSettingInfo(settingKey)
	if not settingInfo then
		return nil
	end
	if settingInfo.default ~= nil then
		return settingInfo.default
	end
	return settingInfo.value
end

function PlayerService.syncPlayerAttributes(player: Player)
	if not PlayerDataServer.hasLoaded(player) then
		return
	end

	local info = PlayerDataServer.getValue(player, PlayerDataKey.Info)
	local lv = if type(info) == "table" and type(info.lv) == "number" and info.lv > 0 then info.lv else 1
	player:SetAttribute(AttributeEnum.Lv, lv)
	player:SetAttribute(AttributeEnum.Player.lv, lv)

	local setting = PlayerDataServer.getValue(player, PlayerDataKey.Setting)
	if type(setting) == "table" then
		for settingKey, value in pairs(setting) do
			if typeof(value) ~= "table" then
				player:SetAttribute(settingKey, value)
			end
		end
	end
end

function PlayerService.hasGamepass(player: Player, gamepassId: number): boolean
	local store = PlayerDataServer.getValue(player, PlayerDataKey.Store)
	local gamepasses = type(store) == "table" and store.gamepass or nil
	return type(gamepasses) == "table" and table.find(gamepasses, gamepassId) ~= nil
end

function PlayerService.addItems(player: Player, itemKey: string, count: number?)
	local value = count or 1
	if value <= 0 then
		return
	end

	PlayerDataServer.updateValue(player, PlayerDataKey.Items, function(items)
		items = ensureTable(items)
		items[itemKey] = (tonumber(items[itemKey]) or 0) + value
		return items
	end)
end

function PlayerService.useItems(player: Player, itemKey: string, count: number?): boolean
	local value = count or 1
	if value <= 0 then
		return false
	end

	local isCovered = false
	PlayerDataServer.updateValue(player, PlayerDataKey.Items, function(items)
		items = ensureTable(items)
		local oldValue = tonumber(items[itemKey]) or 0
		if oldValue >= value then
			local nextValue = oldValue - value
			items[itemKey] = if nextValue > 0 then nextValue else nil
			isCovered = true
		end
		return items
	end)

	return isCovered
end

function PlayerService.addCash(
	player: Player,
	cashKey: string,
	count: number,
	transactionType: string?,
	itemSku: string?,
	customFields: { [string]: number }?
)
	local amount = math.floor(count)
	if amount <= 0 then
		return
	end

	local newBalance = 0
	PlayerDataServer.updateValue(player, PlayerDataKey.Currency, function(currency)
		currency = ensureTable(currency)
		local oldValue = math.floor(tonumber(currency[cashKey]) or 0)
		local newValue = oldValue + amount
		currency[cashKey] = newValue
		newBalance = newValue
		return currency
	end)

	AnalyticsManager.source(player, cashKey, amount, newBalance, transactionType or TransactionEnum.Gameplay, itemSku, customFields)

	if cashKey == CashKey.Cash then
		StatisticManager.add(player, {
			[StatisticKeys.earn_cash] = amount,
		})
	end
end

function PlayerService.reduceCash(
	player: Player,
	cashKey: string,
	count: number,
	transactionType: string?,
	itemSku: string?,
	customFields: { [string]: number }?
): boolean
	return PlayerCurrencySpend.reduce(player, cashKey, count, transactionType or TransactionEnum.Gameplay, itemSku, customFields)
end

function PlayerService.addExp(player: Player, exp: number)
	if exp <= 0 then
		return
	end

	PlayerDataServer.updateValue(player, PlayerDataKey.Info, function(info)
		info = ensureTable(info)
		info.lv = if type(info.lv) == "number" and info.lv > 0 then info.lv else 1
		info.exp = (tonumber(info.exp) or 0) + exp

		local maxExp = CategoryConfig.GetPlayerMaxExp(info.lv)
		while info.exp >= maxExp do
			info.exp -= maxExp
			info.lv += 1
			maxExp = CategoryConfig.GetPlayerMaxExp(info.lv)
		end

		player:SetAttribute(AttributeEnum.Lv, info.lv)
		player:SetAttribute(AttributeEnum.Player.lv, info.lv)
		return info
	end)

	local currentInfo = PlayerDataServer.getValue(player, PlayerDataKey.Info)
	if type(currentInfo) == "table" then
		StatisticManager.set(player, { [StatisticKeys.lv] = currentInfo.lv or 1 })
	end
	StatisticManager.add(player, { [StatisticKeys.exp] = exp })
end

function PlayerService.getRewards(
	player: Player,
	rewards: { RewardItem },
	transactionType: string?,
	itemSku: string?,
	customFields: { [string]: number }?
)
	for _, reward in ipairs(rewards or {}) do
		local value = tonumber(reward.value) or 0
		if value <= 0 then
			continue
		end

		if reward.category == PlayerDataKey.Currency then
			PlayerService.addCash(player, reward.itemKey, value, transactionType or TransactionEnum.TimedReward, itemSku, customFields)
		elseif reward.category == PlayerDataKey.Items then
			PlayerService.addItems(player, reward.itemKey, value)
		end
	end
end

function PlayerService.refreshData(player: Player)
	if not PlayerDataServer.hasLoaded(player) then
		return
	end

	PlayerDataServer.updateValue(player, PlayerDataKey.Date, function(dateData)
		dateData = ensureTable(dateData)
		dateData.timestamp = ensureTable(dateData.timestamp)
		dateData.sign = ensureTable(dateData.sign)
		dateData.online = ensureTable(dateData.online)

		local RefreshService = require(ServerScriptService.ServerCode.GameLogic.Service.Sync.RefreshService)
		local serverTimestamps = RefreshService.Timestamps

		for timeKey, stamp in pairs(serverTimestamps) do
			if dateData.timestamp[timeKey] ~= stamp then
				dateData.timestamp[timeKey] = stamp
				if timeKey == TimestampCategory.daily then
					dateData.sign.claim = false
					dateData.online = { minute = 0, claimedIndex = 0 }
					StatisticManager.reset(player, timeKey)
				elseif timeKey == TimestampCategory.weekly then
					StatisticManager.reset(player, timeKey)
				end
			end
		end

		dateData.sign.index = tonumber(dateData.sign.index) or 0
		dateData.sign.loop = tonumber(dateData.sign.loop) or 1
		dateData.sign.claim = dateData.sign.claim == true
		dateData.online.minute = tonumber(dateData.online.minute) or 0
		dateData.online.claimedIndex = tonumber(dateData.online.claimedIndex) or 0
		dateData.eventRewardClaimedEventIds = ensureTable(dateData.eventRewardClaimedEventIds)

		return dateData
	end)

	PlayerService.syncPlayerAttributes(player)
end

function PlayerService.refreshVotedList(player: Player)
	PlayerDataServer.updateValue(player, PlayerDataKey.Store, function(store)
		store = ensureTable(store)
		store.adReward = { dayStamp = 0, countToday = 0, lastWatchAt = 0 }
		return store
	end)
end

local function changeSettings(player: Player, key: string, value: any): (boolean, any)
	local settingInfo = getSettingInfo(key)
	if not settingInfo then
		return false, "Error: Key not found"
	end

	local defaultValue = getSettingDefault(key)
	if defaultValue ~= nil and typeof(defaultValue) ~= typeof(value) then
		return false, "Error: Type mismatch"
	end

	if typeof(value) == "number" then
		local minValue = if type(settingInfo.min) == "number" then settingInfo.min else 0
		local maxValue = if type(settingInfo.max) == "number" then settingInfo.max else 100
		local stepValue = if type(settingInfo.step) == "number" then math.max(settingInfo.step, 1) else 1
		value = math.clamp(minValue + math.round((value - minValue) / stepValue) * stepValue, minValue, maxValue)
	end

	PlayerDataServer.updateValue(player, PlayerDataKey.Setting, function(setting)
		setting = ensureTable(setting)
		setting[key] = value
		return setting
	end)

	if typeof(value) ~= "table" then
		player:SetAttribute(key, value)
	end

	return true, value
end

local function updateFriendLuck(player: Player)
	local lastUpdate = friendLuckDebounce[player]
	if lastUpdate and os.time() - lastUpdate < FRIEND_LUCK_COOLDOWN then
		return
	end
	friendLuckDebounce[player] = os.time()

	task.spawn(function()
		if not player.Parent then
			return
		end

		local boost = FRIEND_BOOST_MIN
		for _, otherPlayer in ipairs(Players:GetPlayers()) do
			if otherPlayer == player then
				continue
			end

			local success, isFriend = pcall(function()
				return player:IsFriendsWith(otherPlayer.UserId)
			end)
			if success and isFriend then
				boost += FRIEND_BOOST_PER_FRIEND
			end
		end

		if player.Parent then
			player:SetAttribute(AttributeEnum.FriendLuck, math.clamp(boost, FRIEND_BOOST_MIN, FRIEND_BOOST_MAX))
		end
	end)
end

local function markFavorite(player: Player)
	PlayerDataServer.updateValue(player, PlayerDataKey.Info, function(info)
		info = ensureTable(info)
		info.favorite = true
		return info
	end)
end

local function addOnlineMinute(player: Player)
	if not PlayerDataServer.hasLoaded(player) then
		return
	end

	PlayerDataServer.updateValue(player, PlayerDataKey.Date, function(dateData)
		dateData = ensureTable(dateData)
		dateData.online = ensureTable(dateData.online)
		dateData.online.minute = (tonumber(dateData.online.minute) or 0) + 1
		dateData.online.claimedIndex = tonumber(dateData.online.claimedIndex) or 0
		return dateData
	end)
	StatisticManager.add(player, { [StatisticKeys.online] = 1 })
end

function PlayerService.getStatistic(player: Player, statisticKey: string): number
	return StatisticManager.get(player, StatisticTypeCategory.all, statisticKey) or 0
end

-- 好友同服 Cash 加成倍率（1 = 无加成，由 updateFriendLuck 写入 _friendLuck）
function PlayerService.getFriendBoostMultiplier(player: Player): number
	return (player:GetAttribute(AttributeEnum.FriendLuck) :: number?) or FRIEND_BOOST_MIN
end

function PlayerService.listen()
	Network.bindFunction(RemoteFunctionKey.Change_Settings, function(player, key, value)
		return changeSettings(player, key, value)
	end, Network.t.tuple(Network.t.string, Network.t.any))

	Network.connectEvent(RemoteEventKey.FriendLuck, updateFriendLuck)
	Network.connectEvent(RemoteEventKey.SetFavorite, markFavorite)
end

function PlayerService.start()
	Players.PlayerRemoving:Connect(function(player)
		friendLuckDebounce[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(ONLINE_INCREMENT_SECONDS)
			for _, player in ipairs(Players:GetPlayers()) do
				addOnlineMinute(player)
			end
		end
	end)
end

return PlayerService
