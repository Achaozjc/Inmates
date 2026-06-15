--!strict

--[[
	通用货币扣除入口。
	供加载阶段不便直接依赖具体业务服务的模块调用。
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local AnalyticsManager = require(ServerScriptService.ServerCode.Framework.Managers.AnalyticsManager)
local PlayerDataServer = require(ServerScriptService.ServerCode.Framework.DataStore.PlayerData.PlayerDataServer)
local StatisticManager = require(ServerScriptService.ServerCode.Framework.Managers.StatisticManager)

local CashKey = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.CashKey)
local PlayerDataKey = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.PlayerDataKey)
local StatisticKeys = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.StatisticKeys)

local PlayerCurrencySpend = {}

function PlayerCurrencySpend.reduce(
	player: Player,
	cashKey: string,
	count: number,
	transactionType: string,
	itemSku: string?,
	customFields: { [string]: number }?
): boolean
	local isCovered = false
	local spendAmount = math.floor(count)
	if spendAmount <= 0 then
		return false
	end

	PlayerDataServer.updateValue(player, PlayerDataKey.Currency, function(currency)
		currency = currency or {}
		local balance = math.floor(tonumber(currency[cashKey]) or 0)
		if balance >= spendAmount then
			local newValue = math.max(balance - spendAmount, 0)
			currency[cashKey] = newValue
			isCovered = true
			AnalyticsManager.sink(player, cashKey, spendAmount, newValue, transactionType, itemSku, customFields)
		end
		return currency
	end)

	if isCovered and cashKey == CashKey.Cash then
		StatisticManager.add(player, {
			[StatisticKeys.spend_cash] = spendAmount,
		})
	end

	return isCovered
end

return PlayerCurrencySpend
