--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CashKey = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.CashKey)
local ItemKeyCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.ItemKeyCategory)
local SeasonPassRewardCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Enums.SeasonPassRewardCategory)
local ShowUnitNum = require(ReplicatedStorage.ReplicatedCode.Framework.UI.ShowUnitNum)

local DISPLAY_NAMES = {
	[ItemKeyCategory.luck1] = "Luck Boost",
	[ItemKeyCategory.luck2] = "Advanced Luck Boost",
	[ItemKeyCategory.moveSpeed] = "Move Speed Boost",
	[ItemKeyCategory.autoCollect] = "Auto Collect",
	[ItemKeyCategory.serverLuck] = "Server Luck",
	[ItemKeyCategory.enchant1] = "Enchant Token",
	[ItemKeyCategory.enchant2] = "Advanced Enchant Token",
	[ItemKeyCategory.SpinTicket] = "Spin Ticket",
}

local SeasonPassRewardDisplayName = {}

function SeasonPassRewardDisplayName.get(entry: any): string
	if type(entry) ~= "table" then
		return ""
	end
	if type(entry.name) == "string" and entry.name ~= "" then
		return entry.name
	end

	local category = entry.category
	if category == SeasonPassRewardCategory.Cash or entry.itemKey == CashKey.Cash then
		local value = tonumber(entry.value) or 0
		return string.format("%s Cash", ShowUnitNum(value))
	end

	local itemKey = entry.itemKey
	if type(itemKey) == "string" and itemKey ~= "" then
		return DISPLAY_NAMES[itemKey] or itemKey
	end
	if type(category) == "string" and category ~= "" then
		return category
	end
	return ""
end

return SeasonPassRewardDisplayName
