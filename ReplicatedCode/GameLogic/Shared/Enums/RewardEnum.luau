--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CashKey = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.CashKey)
local ItemKeyCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.ItemKeyCategory)
local PlayerDataKey = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.PlayerDataKey)

local function reward(category: string, itemKey: string, value: number): any
	return {
		category = category,
		itemKey = itemKey,
		value = value,
	}
end

local RewardEnum = {}

RewardEnum.Daily = {
	{
		reward(PlayerDataKey.Currency, CashKey.Cash, 250),
	},
	{
		reward(PlayerDataKey.Currency, CashKey.Cash, 500),
	},
	{
		reward(PlayerDataKey.Items, ItemKeyCategory.luck1, 1),
	},
	{
		reward(PlayerDataKey.Currency, CashKey.Cash, 1000),
	},
	{
		reward(PlayerDataKey.Items, ItemKeyCategory.SpinTicket, 1),
	},
	{
		reward(PlayerDataKey.Items, ItemKeyCategory.luck2, 1),
	},
	{
		reward(PlayerDataKey.Currency, CashKey.Cash, 2500),
		reward(PlayerDataKey.Items, ItemKeyCategory.SpinTicket, 2),
	},
}

RewardEnum.Online = {
	{
		minutes = 5,
		rewards = {
			reward(PlayerDataKey.Currency, CashKey.Cash, 100),
		},
	},
	{
		minutes = 10,
		rewards = {
			reward(PlayerDataKey.Currency, CashKey.Cash, 250),
		},
	},
	{
		minutes = 20,
		rewards = {
			reward(PlayerDataKey.Items, ItemKeyCategory.luck1, 1),
		},
	},
	{
		minutes = 30,
		rewards = {
			reward(PlayerDataKey.Items, ItemKeyCategory.SpinTicket, 1),
		},
	},
}

RewardEnum.Spin = {}
RewardEnum.Group = {}

function RewardEnum.getSignLoopIndex(loopValue: any): number
	local loopIndex = tonumber(loopValue) or 1
	return math.max(1, math.floor(loopIndex))
end

function RewardEnum.getSignRewardsByLoop(_loopValue: any): { any }
	return RewardEnum.Daily
end

return RewardEnum
