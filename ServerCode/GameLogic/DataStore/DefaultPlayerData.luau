--!strict

--[[
	新项目默认玩家数据骨架。
	保留通用系统需要的根字段；具体玩法数据后续从这里扩展。
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CashKey = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.CashKey)
local AxeCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.AxeCategory)
local ChestCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.ChestCategory)
local CashMultiplierConfig = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Configs.CashMultiplierConfig)

export type PlayerData = { [string]: any }

-- 合法宝箱 category 值集合（用于 heldChest 校验）
local VALID_CHEST_CATEGORIES: { [string]: boolean } = {}
for _, value in ChestCategory do
	VALID_CHEST_CATEGORIES[value] = true
end

-- 合法斧头 category 值集合（用于 discoveredAxes 图鉴校验）
local VALID_AXE_CATEGORIES: { [string]: boolean } = {}
for _, value in AxeCategory do
	VALID_AXE_CATEGORIES[value] = true
end

local DEFAULT_DATA: PlayerData = {
	-- Cash：已领取现金；PendingCash：处理机产出、待 CollectMoney 领取（持久化，重连不丢）
	Currency = {
		[CashKey.Cash] = 10,
		[CashKey.PendingCash] = 0,
	},

	-- 斧头大亨核心玩法数据
	AxeTycoon = {
		axes = {}, -- 稀疏 map：["floor_slot"]=斧头 category，如 ["3_7"]="2"
		discoveredAxes = {}, -- 图鉴已解锁 set：{ [斧头 category]=true }，曾拥有过即永久记录（含合成途经的中间稀有度）
		ownedAxeCount = 0, -- 累计拥有斧头数（只增不减；买斧 +购买数量，合成不减少），用于斧子动态定价
		carrying = {}, -- 背上木头 { [woodCategory]=件数 }，持久化防掉线丢失
		processorStock = 0, -- 处理机待加工量（单一数值，已乘木料倍率的待变现池）
		processorUpgradeCount = 0, -- 产能升级次数（初始 0，决定每秒加工数与升级价格）
		cashMultiplierTier = 0, -- Cash 倍率付费档位（0=未购买，1..MaxTier 见 CashMultiplierConfig）
		heldChest = false, -- 手持的未开启宝箱（ChestCategory 值；false 表示未持有），持久化、同时仅一个
		lastGroupRewardAt = 0, -- 上次领取群组奖励的 Unix 时间（0=从未领取），见 GroupRewardService
		offlineLastSeenAt = 0, -- 上次在线时间戳（Unix，秒）；进服据此结算离线木料，见 OfflineWoodService
		pendingOfflineWood = 0, -- 未领取的离线木料（触碰木堆领取后转入 processorStock）
	},

	Info = {
		userId = 0,
		createdAt = 0,
		lastLoginTime = 0,
		lv = 1,
		exp = 0,
		favorite = false,
		oxygenMax = 100,
	},

	Setting = {},
	Codes = {},
	Store = {
		gamepass = {},
		adReward = {
			dayStamp = 0,
			countToday = 0,
			lastWatchAt = 0,
		},
	},
	Items = {},
	Statistic = {},
	AFK = {},
	Tags = {},
	LimitedStore = {},
	Battlepass = {},
	Invite = {},
	Vote = {},
	Zone = {},
	Potion = {},
	-- 新手教程完成标记（每步完成后由 TutorialService 置 true，永不回退）
	Tutorial = {
		newbie = {
			buyAxeDone = false,
			collectWoodDone = false,
			depositWoodDone = false,
			collectCashDone = false,
			upgradeDone = false,
		},
	},
	SeasonPass = {},
	BadgeClaimed = {},
	LeaderboardClaim = {},
	Titles = {},

	Date = {
		timestamp = {},
		sign = {
			index = 0,
			claim = false,
			loop = 1,
		},
		online = {
			minute = 0,
			claimedIndex = 0,
		},
		eventRewardClaimedEventIds = {},
	},
}

local PlayerData = {}

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end

	local copy = {}
	for key, child in pairs(value) do
		copy[key] = deepCopy(child)
	end
	return copy
end

local function reconcile(source: any, template: any): any
	local output = if type(source) == "table" then deepCopy(source) else {}

	for key, defaultValue in pairs(template) do
		if output[key] == nil then
			output[key] = deepCopy(defaultValue)
		elseif type(output[key]) == "table" and type(defaultValue) == "table" then
			output[key] = reconcile(output[key], defaultValue)
		end
	end

	return output
end

local function reconcileCurrency(currency: any): any
	local reconciled = reconcile(currency, DEFAULT_DATA.Currency)
	reconciled[CashKey.Cash] = math.floor(tonumber(reconciled[CashKey.Cash]) or DEFAULT_DATA.Currency[CashKey.Cash])
	reconciled[CashKey.PendingCash] = math.floor(tonumber(reconciled[CashKey.PendingCash]) or 0)
	return reconciled
end

local function reconcileCarrying(carrying: any): { [string]: number }
	if type(carrying) ~= "table" then
		return {}
	end

	local normalized: { [string]: number } = {}
	for category, count in carrying do
		local pieceCount = tonumber(count)
		if pieceCount and pieceCount > 0 then
			normalized[category] = math.floor(pieceCount)
		end
	end
	return normalized
end

-- 图鉴已解锁 set：仅保留合法斧头 category 且值为 true 的条目
local function reconcileDiscoveredAxes(discoveredAxes: any): { [string]: boolean }
	if type(discoveredAxes) ~= "table" then
		return {}
	end

	local normalized: { [string]: boolean } = {}
	for category, unlocked in discoveredAxes do
		if unlocked and VALID_AXE_CATEGORIES[category] then
			normalized[category] = true
		end
	end
	return normalized
end

local function reconcileAxeTycoon(axeTycoon: any): any
	local reconciled = reconcile(axeTycoon, DEFAULT_DATA.AxeTycoon)
	reconciled.carrying = reconcileCarrying(reconciled.carrying)
	reconciled.discoveredAxes = reconcileDiscoveredAxes(reconciled.discoveredAxes)
	reconciled.processorStock = tonumber(reconciled.processorStock) or 0
	reconciled.processorUpgradeCount = math.max(0, math.floor(tonumber(reconciled.processorUpgradeCount) or 0))
	reconciled.cashMultiplierTier = math.clamp(math.floor(tonumber(reconciled.cashMultiplierTier) or 0), 0, CashMultiplierConfig.MaxTier)
	reconciled.ownedAxeCount = math.max(0, math.floor(tonumber(reconciled.ownedAxeCount) or 0))
	reconciled.lastGroupRewardAt = math.max(0, math.floor(tonumber(reconciled.lastGroupRewardAt) or 0))
	reconciled.offlineLastSeenAt = math.max(0, math.floor(tonumber(reconciled.offlineLastSeenAt) or 0))
	reconciled.pendingOfflineWood = math.max(0, math.floor(tonumber(reconciled.pendingOfflineWood) or 0))
	reconciled.axes = if type(reconciled.axes) == "table" then reconciled.axes else {}
	-- 图鉴自愈：当前占用的斧子稀有度并入 discoveredAxes（兼容旧存档、防止漏记）
	for _, category in reconciled.axes do
		if VALID_AXE_CATEGORIES[category] then
			reconciled.discoveredAxes[category] = true
		end
	end
	-- heldChest：仅接受合法的 ChestCategory 值，否则归为 false（未持有）
	local heldChest = reconciled.heldChest
	reconciled.heldChest = if type(heldChest) == "string" and VALID_CHEST_CATEGORIES[heldChest]
		then heldChest
		else false
	return reconciled
end

-- Studio 测试用：是否给新数据预置 99 个 3 级斧子（仅 Studio 生效，线上默认数据不受影响）
local STUDIO_SEED_99_AXE3 = false

-- 构建 99 个 3 级斧子的 axes map（按 "floor_slot" 占满前 99 个槽位）
local function buildStudioSeedAxes(): { [string]: string }
	local axes: { [string]: string } = {}
	local placed = 0
	for floor = 1, 10 do
		for slot = 1, 10 do
			if placed >= 99 then
				return axes
			end
			axes[floor .. "_" .. slot] = AxeCategory.Axe_3
			placed += 1
		end
	end
	return axes
end

function PlayerData.GetDefaultData(userId: number): PlayerData
	local data = deepCopy(DEFAULT_DATA)
	local now = os.time()
	data.Info.userId = userId
	data.Info.createdAt = now
	data.Info.lastLoginTime = now

	-- 仅 Studio：预置 99 个 3 级斧子（每个 3 级 = 9 个 1 级合成而来，故 ownedAxeCount = 99 × 9）
	-- 同时给充足现金，便于测试买斧 / 开箱
	if STUDIO_SEED_99_AXE3 and RunService:IsStudio() then
		data.AxeTycoon.axes = buildStudioSeedAxes()
		data.AxeTycoon.ownedAxeCount = 99 * 9
		data.Currency[CashKey.Cash] = 9999 -- 1B
	end

	return data
end

function PlayerData.Reconcile(data: any): PlayerData
	local output = reconcile(data, DEFAULT_DATA)
	output.Currency = reconcileCurrency(output.Currency)
	output.AxeTycoon = reconcileAxeTycoon(output.AxeTycoon)
	return output
end

return PlayerData
