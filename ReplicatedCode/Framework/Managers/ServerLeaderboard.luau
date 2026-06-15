--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataServer = require(ServerScriptService.ServerCode.Framework.DataStore.PlayerData.PlayerDataServer)
local PlayerDataKey = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.PlayerDataKey)
local CashKey = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.CashKey)
local showUnitNum = require(ReplicatedStorage.ReplicatedCode.Framework.UI.ShowUnitNum)

local Leaderboard = {}

local MONEY_STAT_NAME = "Cash"
local LEVEL_STAT_NAME = "Level"
local playerStatCache = {} :: {
	[Player]: {
		cashRaw: number?,
		cashText: string?,
		lv: number?,
	}
}

local function setupLeaderboard(player: Player): Folder
	local leaderstats = player:FindFirstChild("leaderstats") :: Folder?
	if leaderstats then
		return leaderstats
	end

	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	folder.Parent = player
	return folder
end

local function setupIntStat(leaderstats: Folder, statName: string): IntValue
	local stat = leaderstats:FindFirstChild(statName) :: IntValue?
	if stat then
		return stat
	end

	local value = Instance.new("IntValue")
	value.Name = statName
	value.Value = 0
	value.Parent = leaderstats
	return value
end

local function setupStringStat(leaderstats: Folder, statName: string): StringValue
	local stat = leaderstats:FindFirstChild(statName) :: StringValue?
	if stat then
		return stat
	end

	local value = Instance.new("StringValue")
	value.Name = statName
	value.Value = "0"
	value.Parent = leaderstats
	return value
end

function Leaderboard.setStat(player: Player, statName: string, value: number)
	local leaderstats = setupLeaderboard(player)
	local stat = setupIntStat(leaderstats, statName)
	local nextValue = math.floor(value)
	if stat.Value == nextValue then
		return
	end
	stat.Value = nextValue
end

function Leaderboard.setTextStat(player: Player, statName: string, value: string)
	local leaderstats = setupLeaderboard(player)
	local stat = setupStringStat(leaderstats, statName)
	if stat.Value == value then
		return
	end
	stat.Value = value
end

local function syncPlayerLeaderboard(player: Player)
	if not PlayerDataServer.hasLoaded(player) then
		return
	end

	local currency = PlayerDataServer.getValue(player, PlayerDataKey.Currency)
	local info = PlayerDataServer.getValue(player, PlayerDataKey.Info)

	local cash = 0
	if currency and typeof(currency[CashKey.Cash]) == "number" then
		cash = currency[CashKey.Cash]
	end

	local lv = 1
	if info and typeof(info.lv) == "number" then
		lv = info.lv
	end

	local cache = playerStatCache[player]
	if not cache then
		cache = {}
		playerStatCache[player] = cache
	end

	if cache.cashRaw ~= cash then
		cache.cashRaw = cash
		cache.cashText = showUnitNum(cash)
	end

	if cache.cashText then
		Leaderboard.setTextStat(player, MONEY_STAT_NAME, cache.cashText)
	end

	if cache.lv ~= lv then
		cache.lv = lv
		Leaderboard.setStat(player, LEVEL_STAT_NAME, lv)
	end
end

function Leaderboard.start()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			if not PlayerDataServer.hasLoaded(player) then
				PlayerDataServer.waitForDataLoadAsync(player)
			end

			if player.Parent then
				syncPlayerLeaderboard(player)
			end
		end)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			if not PlayerDataServer.hasLoaded(player) then
				PlayerDataServer.waitForDataLoadAsync(player)
			end

			if player.Parent then
				syncPlayerLeaderboard(player)
			end
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		playerStatCache[player] = nil
	end)

	PlayerDataServer.playerDataUpdated:Connect(function(player, valueName)
		if typeof(player) ~= "Instance" or not player:IsA("Player") then
			return
		end

		if valueName == PlayerDataKey.Currency or valueName == PlayerDataKey.Info then
			syncPlayerLeaderboard(player)
		end
	end)
end

return Leaderboard
