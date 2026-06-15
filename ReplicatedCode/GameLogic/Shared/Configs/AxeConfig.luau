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
	},
	[AxeCategory.Axe_2] = {
		name = "Oak",
		rarity = 2,
		cd = 4,
		wood = WoodCategory.Wood_2,
	},
	[AxeCategory.Axe_3] = {
		name = "Pine",
		rarity = 3,
		cd = 4,
		wood = WoodCategory.Wood_3,
	},
	[AxeCategory.Axe_4] = {
		name = "Birch",
		rarity = 4,
		cd = 4,
		wood = WoodCategory.Wood_4,
	},
	[AxeCategory.Axe_5] = {
		name = "Maple",
		rarity = 5,
		cd = 4,
		wood = WoodCategory.Wood_5,
	},
	[AxeCategory.Axe_6] = {
		name = "Cedar",
		rarity = 6,
		cd = 4,
		wood = WoodCategory.Wood_6,
	},
	[AxeCategory.Axe_7] = {
		name = "Willow",
		rarity = 7,
		cd = 4,
		wood = WoodCategory.Wood_7,
	},
	[AxeCategory.Axe_8] = {
		name = "Walnut",
		rarity = 8,
		cd = 4,
		wood = WoodCategory.Wood_8,
	},
	[AxeCategory.Axe_9] = {
		name = "Cherry",
		rarity = 9,
		cd = 4,
		wood = WoodCategory.Wood_9,
	},
	[AxeCategory.Axe_10] = {
		name = "Bamboo",
		rarity = 10,
		cd = 4,
		wood = WoodCategory.Wood_10,
	},
	[AxeCategory.Axe_11] = {
		name = "Teak",
		rarity = 11,
		cd = 4,
		wood = WoodCategory.Wood_11,
	},
	[AxeCategory.Axe_12] = {
		name = "Mahogany",
		rarity = 12,
		cd = 4,
		wood = WoodCategory.Wood_12,
	},
	[AxeCategory.Axe_13] = {
		name = "Ash",
		rarity = 13,
		cd = 4,
		wood = WoodCategory.Wood_13,
	},
	[AxeCategory.Axe_14] = {
		name = "Elm",
		rarity = 14,
		cd = 4,
		wood = WoodCategory.Wood_14,
	},
	[AxeCategory.Axe_15] = {
		name = "Spruce",
		rarity = 15,
		cd = 4,
		wood = WoodCategory.Wood_15,
	},
	[AxeCategory.Axe_16] = {
		name = "Fir",
		rarity = 16,
		cd = 4,
		wood = WoodCategory.Wood_16,
	},
	[AxeCategory.Axe_17] = {
		name = "Redwood",
		rarity = 17,
		cd = 4,
		wood = WoodCategory.Wood_17,
	},
	[AxeCategory.Axe_18] = {
		name = "Cypress",
		rarity = 18,
		cd = 4,
		wood = WoodCategory.Wood_18,
	},
	[AxeCategory.Axe_19] = {
		name = "Hickory",
		rarity = 19,
		cd = 4,
		wood = WoodCategory.Wood_19,
	},
	[AxeCategory.Axe_20] = {
		name = "Poplar",
		rarity = 20,
		cd = 4,
		wood = WoodCategory.Wood_20,
	},
	[AxeCategory.Axe_21] = {
		name = "Beech",
		rarity = 21,
		cd = 4,
		wood = WoodCategory.Wood_21,
	},
	[AxeCategory.Axe_22] = {
		name = "Alder",
		rarity = 22,
		cd = 4,
		wood = WoodCategory.Wood_22,
	},
	[AxeCategory.Axe_23] = {
		name = "Larch",
		rarity = 23,
		cd = 4,
		wood = WoodCategory.Wood_23,
	},
	[AxeCategory.Axe_24] = {
		name = "Ebony",
		rarity = 24,
		cd = 4,
		wood = WoodCategory.Wood_24,
	},
}

return AxeConfig
