--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StatisticKeys = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.StatisticKeys)

local StatisticEnum = {
	{
		name = "Online Time",
		key = StatisticKeys.online,
	},
	{
		name = "Cash Earned",
		key = StatisticKeys.earn_cash,
	},
	{
		name = "Robux Spent",
		key = StatisticKeys.spend_robux,
	},
}

return StatisticEnum
