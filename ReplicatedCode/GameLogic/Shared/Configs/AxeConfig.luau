local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AxeCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.AxeCategory)
local WoodCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.WoodCategory)

local AxeConfig = {}

AxeConfig.Axes = {
	[AxeCategory.Axe_1] = {
		name = "Wood",
		rarity = 1,
		cd = 4,
		wood = WoodCategory.Wood_1,
		-- 砍木动画 ID 占位：填 0 表示沿用默认动画，后续替换为各单位专属动画 ID
		animation = 0,
	},
	[AxeCategory.Axe_2] = {
		name = "Oak",
		rarity = 2,
		cd = 4,
		wood = WoodCategory.Wood_2,
		animation = 0,
	},
	[AxeCategory.Axe_3] = {
		name = "Pine",
		rarity = 3,
		cd = 4,
		wood = WoodCategory.Wood_3,
		animation = 0,
	},
	[AxeCategory.Axe_4] = {
		name = "Birch",
		rarity = 4,
		cd = 4,
		wood = WoodCategory.Wood_4,
		animation = 0,
	},
	[AxeCategory.Axe_5] = {
		name = "Maple",
		rarity = 5,
		cd = 4,
		wood = WoodCategory.Wood_5,
		animation = 0,
	},
	[AxeCategory.Axe_6] = {
		name = "Cedar",
		rarity = 6,
		cd = 4,
		wood = WoodCategory.Wood_6,
		animation = 0,
	},
	[AxeCategory.Axe_7] = {
		name = "Willow",
		rarity = 7,
		cd = 4,
		wood = WoodCategory.Wood_7,
		animation = 0,
	},
	[AxeCategory.Axe_8] = {
		name = "Walnut",
		rarity = 8,
		cd = 4,
		wood = WoodCategory.Wood_8,
		animation = 0,
	},
	[AxeCategory.Axe_9] = {
		name = "Cherry",
		rarity = 9,
		cd = 4,
		wood = WoodCategory.Wood_9,
		animation = 0,
	},
	[AxeCategory.Axe_10] = {
		name = "Bamboo",
		rarity = 10,
		cd = 4,
		wood = WoodCategory.Wood_10,
		animation = 0,
	},
	[AxeCategory.Axe_11] = {
		name = "Teak",
		rarity = 11,
		cd = 4,
		wood = WoodCategory.Wood_11,
		animation = 0,
	},
	[AxeCategory.Axe_12] = {
		name = "Mahogany",
		rarity = 12,
		cd = 4,
		wood = WoodCategory.Wood_12,
		animation = 0,
	},
	[AxeCategory.Axe_13] = {
		name = "Ash",
		rarity = 13,
		cd = 4,
		wood = WoodCategory.Wood_13,
		animation = 0,
	},
	[AxeCategory.Axe_14] = {
		name = "Elm",
		rarity = 14,
		cd = 4,
		wood = WoodCategory.Wood_14,
		animation = 0,
	},
	[AxeCategory.Axe_15] = {
		name = "Spruce",
		rarity = 15,
		cd = 4,
		wood = WoodCategory.Wood_15,
		animation = 0,
	},
	[AxeCategory.Axe_16] = {
		name = "Fir",
		rarity = 16,
		cd = 4,
		wood = WoodCategory.Wood_16,
		animation = 0,
	},
	[AxeCategory.Axe_17] = {
		name = "Redwood",
		rarity = 17,
		cd = 4,
		wood = WoodCategory.Wood_17,
		animation = 0,
	},
	[AxeCategory.Axe_18] = {
		name = "Cypress",
		rarity = 18,
		cd = 4,
		wood = WoodCategory.Wood_18,
		animation = 0,
	},
	[AxeCategory.Axe_19] = {
		name = "Hickory",
		rarity = 19,
		cd = 4,
		wood = WoodCategory.Wood_19,
		animation = 0,
	},
	[AxeCategory.Axe_20] = {
		name = "Poplar",
		rarity = 20,
		cd = 4,
		wood = WoodCategory.Wood_20,
		animation = 0,
	},
	[AxeCategory.Axe_21] = {
		name = "Beech",
		rarity = 21,
		cd = 4,
		wood = WoodCategory.Wood_21,
		animation = 0,
	},
	[AxeCategory.Axe_22] = {
		name = "Alder",
		rarity = 22,
		cd = 4,
		wood = WoodCategory.Wood_22,
		animation = 0,
	},
	[AxeCategory.Axe_23] = {
		name = "Larch",
		rarity = 23,
		cd = 4,
		wood = WoodCategory.Wood_23,
		animation = 0,
	},
	[AxeCategory.Axe_24] = {
		name = "Ebony",
		rarity = 24,
		cd = 4,
		wood = WoodCategory.Wood_24,
		animation = 0,
	},
}

return AxeConfig
