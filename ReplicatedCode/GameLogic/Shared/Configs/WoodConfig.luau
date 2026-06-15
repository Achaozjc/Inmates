local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShowUnitNum = require(ReplicatedStorage.ReplicatedCode.Framework.UI.ShowUnitNum)
local WoodCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.WoodCategory)

local WoodConfig = {}

WoodConfig.Woods = {
	[WoodCategory.Wood_1] = {
		rarity = 1,
		value = 1,
	},
	[WoodCategory.Wood_2] = {
		rarity = 2,
		value = 5,
	},
	[WoodCategory.Wood_3] = {
		rarity = 3,
		value = 24,
	},
	[WoodCategory.Wood_4] = {
		rarity = 4,
		value = 89,
	},
	[WoodCategory.Wood_5] = {
		rarity = 5,
		value = 307,
	},
	[WoodCategory.Wood_6] = {
		rarity = 6,
		value = 1100,
	},
	[WoodCategory.Wood_7] = {
		rarity = 7,
		value = 4000,
	},
	[WoodCategory.Wood_8] = {
		rarity = 8,
		value = 14000,
	},
	[WoodCategory.Wood_9] = {
		rarity = 9,
		value = 49000,
	},
	[WoodCategory.Wood_10] = {
		rarity = 10,
		value = 171500,
	},
	[WoodCategory.Wood_11] = {
		rarity = 11,
		value = 600250,
	},
	[WoodCategory.Wood_12] = {
		rarity = 12,
		value = 2100875,
	},
	[WoodCategory.Wood_13] = {
		rarity = 13,
		value = 7353063,
	},
	[WoodCategory.Wood_14] = {
		rarity = 14,
		value = 25735719,
	},
	[WoodCategory.Wood_15] = {
		rarity = 15,
		value = 90075016,
	},
	[WoodCategory.Wood_16] = {
		rarity = 16,
		value = 315262555,
	},
	[WoodCategory.Wood_17] = {
		rarity = 17,
		value = 1103418941,
	},
	[WoodCategory.Wood_18] = {
		rarity = 18,
		value = 3861966295,
	},
	[WoodCategory.Wood_19] = {
		rarity = 19,
		value = 13516882032,
	},
	[WoodCategory.Wood_20] = {
		rarity = 20,
		value = 47309087113,
	},
	[WoodCategory.Wood_21] = {
		rarity = 21,
		value = 165581804895,
	},
	[WoodCategory.Wood_22] = {
		rarity = 22,
		value = 579536317132,
	},
	[WoodCategory.Wood_23] = {
		rarity = 23,
		value = 2028377109961,
	},
	[WoodCategory.Wood_24] = {
		rarity = 24,
		value = 7099319884863,
	},
}

function WoodConfig.getPieceValue(category: string): number
	local wood = WoodConfig.Woods[category]
	return if wood then wood.value else 0
end

-- 木头数量 UI 展示（K/M/B 缩写，与 Cash 等指标一致）
function WoodConfig.formatWoodQuantity(amount: number): string
	return ShowUnitNum(amount)
end

-- 按 value 加权汇总背负木头（件数 × 单件价值）
function WoodConfig.sumCarryingValue(carrying: any): number
	if type(carrying) ~= "table" then
		return 0
	end

	local total = 0
	for category, count in carrying do
		local pieceCount = tonumber(count) or 0
		if pieceCount > 0 then
			total += pieceCount * WoodConfig.getPieceValue(category)
		end
	end
	return total
end

return WoodConfig
