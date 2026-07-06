local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChestCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.ChestCategory)
local AxeCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.AxeCategory)
local AxeConfig = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Configs.AxeConfig)

local ChestConfig = {}

-- 宝箱存放位上限（Base_*.Chests.ChestPlace 下共 8 个 Attachment 槽位），满则不再生成
ChestConfig.PLACE_LIMIT = 8

-- 付费开启兜底价（Robux）：当某宝箱未单独配置 openRobux 时使用此默认值。
ChestConfig.OPEN_ROBUX = 99

--[[
	宝箱配置（端共享），对应图2。

	字段说明：
		rarity            稀有度等级（与宝箱编号一致）
		spawnChance       生产木头时掉落该宝箱的概率（5%）
		unlockCostPerAxe  金币解锁系数，实际解锁价 = unlockCostPerAxe × 玩家拥有斧头数
		openRobux         Cash 不足时付费开启价（Robux）
		productKey        付费开启对应的开发者商品键（StoreIdCategory.Product）
		existTime         宝箱在场存在时间（秒），超时消失
		axeWeights        开箱可开出的斧头等级及权重（按权重随机抽取一个斧头等级）
]]
ChestConfig.Chests = {
	[ChestCategory.Chest_1] = {
		name = "Common Chest",
		rarity = 1,
		spawnChance = 0.05,
		unlockCostPerAxe = 20,
		openRobux = 19,
		productKey = "ChestOpenCommon",
		existTime = 100,
		axeWeights = {
			[AxeCategory.Axe_4] = 7500,
			[AxeCategory.Axe_5] = 2000,
			[AxeCategory.Axe_6] = 500,
		},
	},
	[ChestCategory.Chest_2] = {
		name = "Uncommon Chest",
		rarity = 2,
		spawnChance = 0.05,
		unlockCostPerAxe = 1000,
		openRobux = 29,
		productKey = "ChestOpenUncommon",
		existTime = 100,
		axeWeights = {
			[AxeCategory.Axe_7] = 7500,
			[AxeCategory.Axe_8] = 2000,
			[AxeCategory.Axe_9] = 500,
		},
	},
	[ChestCategory.Chest_3] = {
		name = "Rare Chest",
		rarity = 3,
		spawnChance = 0.05,
		unlockCostPerAxe = 25000,
		openRobux = 49,
		productKey = "ChestOpenRare",
		existTime = 100,
		axeWeights = {
			[AxeCategory.Axe_10] = 7500,
			[AxeCategory.Axe_11] = 2000,
			[AxeCategory.Axe_12] = 500,
		},
	},
	[ChestCategory.Chest_4] = {
		name = "Epic Chest",
		rarity = 4,
		spawnChance = 0.05,
		unlockCostPerAxe = 1000000, -- 1m
		openRobux = 99,
		productKey = "ChestOpenEpic",
		existTime = 100,
		axeWeights = {
			[AxeCategory.Axe_13] = 6500,
			[AxeCategory.Axe_14] = 2500,
			[AxeCategory.Axe_15] = 800,
			[AxeCategory.Axe_16] = 200,
		},
	},
	[ChestCategory.Chest_5] = {
		name = "Legendary Chest",
		rarity = 5,
		spawnChance = 0.05,
		unlockCostPerAxe = 30000000, -- 30m
		openRobux = 199,
		productKey = "ChestOpenLegendary",
		existTime = 100,
		axeWeights = {
			[AxeCategory.Axe_17] = 6500,
			[AxeCategory.Axe_18] = 2500,
			[AxeCategory.Axe_19] = 800,
			[AxeCategory.Axe_20] = 200,
		},
	},
	[ChestCategory.Chest_6] = {
		name = "Mythic Chest",
		rarity = 6,
		spawnChance = 0.05,
		unlockCostPerAxe = 1000000000, -- 1b
		openRobux = 399,
		productKey = "ChestOpenMythic",
		existTime = 100,
		axeWeights = {
			[AxeCategory.Axe_21] = 6500,
			[AxeCategory.Axe_22] = 2500,
			[AxeCategory.Axe_23] = 800,
			[AxeCategory.Axe_24] = 200,
		},
	},
}

-- 斧头稀有度 -> 生产木头时可掉落的宝箱等级（对应图1「生产宝箱」列；稀有度 1 不掉落宝箱）
ChestConfig.AxeRarityToChest = {
	[2] = ChestCategory.Chest_1,
	[3] = ChestCategory.Chest_1,
	[4] = ChestCategory.Chest_2,
	[5] = ChestCategory.Chest_2,
	[6] = ChestCategory.Chest_2,
	[7] = ChestCategory.Chest_3,
	[8] = ChestCategory.Chest_3,
	[9] = ChestCategory.Chest_3,
	[10] = ChestCategory.Chest_4,
	[11] = ChestCategory.Chest_4,
	[12] = ChestCategory.Chest_4,
	[13] = ChestCategory.Chest_5,
	[14] = ChestCategory.Chest_5,
	[15] = ChestCategory.Chest_5,
	[16] = ChestCategory.Chest_6,
	[17] = ChestCategory.Chest_6,
	[18] = ChestCategory.Chest_6,
	[19] = ChestCategory.Chest_6,
	[20] = ChestCategory.Chest_6,
	[21] = ChestCategory.Chest_6,
	[22] = ChestCategory.Chest_6,
	[23] = ChestCategory.Chest_6,
	[24] = ChestCategory.Chest_6,
}

-- 按斧头稀有度取其掉落的宝箱等级（无对应则返回 nil）
function ChestConfig.getChestForAxeRarity(rarity: number): string?
	return ChestConfig.AxeRarityToChest[rarity]
end

-- 金币解锁价 = 系数 × 玩家拥有斧头数
function ChestConfig.getUnlockCost(category: string, ownedAxeCount: number): number
	local chest = ChestConfig.Chests[category]
	if not chest then
		return 0
	end
	return chest.unlockCostPerAxe * ownedAxeCount
end

-- 宝箱英文名（用于 UI 显示）
function ChestConfig.getChestName(category: string): string
	local chest = ChestConfig.Chests[category]
	return if chest then chest.name else "Chest"
end

-- 该宝箱付费开启价（Robux）；未单独配置则回退到 OPEN_ROBUX
function ChestConfig.getOpenRobux(category: string): number
	local chest = ChestConfig.Chests[category]
	return if chest and chest.openRobux then chest.openRobux else ChestConfig.OPEN_ROBUX
end

-- 该宝箱付费开启对应的开发者商品键（StoreIdCategory.Product）；无则返回 nil
function ChestConfig.getOpenProductKey(category: string): string?
	local chest = ChestConfig.Chests[category]
	return if chest then chest.productKey else nil
end

export type AxeProbability = {
	axeCategory: string, -- AxeCategory 值
	rarity: number, -- 斧头稀有度（Tier）
	name: string, -- 斧头英文名
	percent: number, -- 开出概率百分比（0-100，四舍五入到整数）
}

-- 该宝箱可开出的斧头及概率，按 Tier 升序返回（用于面板逐行展示）
function ChestConfig.getAxeProbabilities(category: string): { AxeProbability }
	local chest = ChestConfig.Chests[category]
	if not chest then
		return {}
	end

	local total = 0
	for _, weight in chest.axeWeights do
		total += weight
	end
	if total <= 0 then
		return {}
	end

	local list: { AxeProbability } = {}
	for axeCategory, weight in chest.axeWeights do
		local axeInfo = AxeConfig.Axes[axeCategory]
		list[#list + 1] = {
			axeCategory = axeCategory,
			rarity = if axeInfo then axeInfo.rarity else 0,
			name = if axeInfo then axeInfo.name else "Axe",
			percent = math.floor(weight / total * 100 + 0.5),
		}
	end

	table.sort(list, function(a, b)
		return a.rarity < b.rarity
	end)
	return list
end

-- 按权重随机抽取该宝箱开出的斧头等级，返回 AxeCategory 值
-- weightAdd：天气加成，加到该宝箱最高稀有度斧头的权重上
function ChestConfig.rollAxe(category: string, weightAdd: number?): string?
	local chest = ChestConfig.Chests[category]
	if not chest then
		return nil
	end

	local adjustedWeights: { [string]: number } = {}
	local topAxeCategory: string? = nil
	local topRarity = -1

	for axeCategory, weight in chest.axeWeights do
		adjustedWeights[axeCategory] = weight
		local axeInfo = AxeConfig.Axes[axeCategory]
		local rarity = if axeInfo then axeInfo.rarity else 0
		if rarity > topRarity then
			topRarity = rarity
			topAxeCategory = axeCategory
		end
	end

	if weightAdd and weightAdd > 0 and topAxeCategory then
		adjustedWeights[topAxeCategory] = (adjustedWeights[topAxeCategory] or 0) + weightAdd
	end

	local total = 0
	for _, weight in adjustedWeights do
		total += weight
	end
	if total <= 0 then
		return nil
	end

	local roll = math.random() * total
	local cumulative = 0
	for axeCategory, weight in adjustedWeights do
		cumulative += weight
		if roll <= cumulative then
			return axeCategory
		end
	end
	return nil
end

return ChestConfig
