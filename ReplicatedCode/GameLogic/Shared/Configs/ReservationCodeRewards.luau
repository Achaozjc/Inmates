--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CashKey = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.CashKey)
local ItemKeyCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.ItemKeyCategory)
local PlayerDataKey = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.PlayerDataKey)

local ReservationCodeRewards = {}

local function reward(category: string, itemKey: string, value: number): any
	return {
		category = category,
		itemKey = itemKey,
		value = value,
	}
end

-- 预生成码池奖励，与 CodeConfig.Codes[code].rewards 保持同形。
ReservationCodeRewards.Rewards = {
	NewPlayerPack = {
		prefix = "NPP",
		expireDays = 14,
		rewards = {
			reward(PlayerDataKey.Currency, CashKey.Cash, 3000),
			reward(PlayerDataKey.Items, ItemKeyCategory.luck1, 1),
		},
	},

	ReturningPlayerPack = {
		prefix = "RPP",
		expireDays = 14,
		rewards = {
			reward(PlayerDataKey.Items, ItemKeyCategory.luck2, 1),
			reward(PlayerDataKey.Items, ItemKeyCategory.SpinTicket, 2),
		},
	},

	MaintenanceCompensation = {
		prefix = "MC",
		expireDays = 14,
		rewards = {
			reward(PlayerDataKey.Items, ItemKeyCategory.enchant1, 1),
			reward(PlayerDataKey.Items, ItemKeyCategory.autoCollect, 1),
		},
	},

	CustomerSupportCompensation = {
		prefix = "CSC",
		expireDays = 30,
		rewards = {
			reward(PlayerDataKey.Items, ItemKeyCategory.enchant2, 2),
			reward(PlayerDataKey.Items, ItemKeyCategory.SpinTicket, 5),
		},
	},
} :: { [string]: { prefix: string?, expireDays: number?, rewards: any } }

return ReservationCodeRewards
