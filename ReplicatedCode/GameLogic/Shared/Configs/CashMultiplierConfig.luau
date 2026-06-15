--!strict

--[[
	Cash 倍率付费档位（端共享）。

	玩家依次购买：初始 1x（未购买），购买后现金倍率替换为对应档位值，最高 40x。
	屏幕按钮始终展示「下一个可购买档位」，购买成功后切换到再下一档；到 40x 隐藏。

	玩家持久化字段：AxeTycoon.cashMultiplierTier（0 表示未购买，1..MaxTier 对应下表 index）。
	倍率在处理机把库存变现为 PendingCash 时生效（见 ProcessorService）。
]]

export type Tier = {
	multiplier: number,
	productKey: string, -- 对应 StoreIdCategory.Product 中的键
}

local CashMultiplierConfig = {}

-- 升序排列；index 即 cashMultiplierTier（1..#Tiers）
CashMultiplierConfig.Tiers = {
	{ multiplier = 2, productKey = "CashMultiplier2x" },
	{ multiplier = 4, productKey = "CashMultiplier4x" },
	{ multiplier = 7, productKey = "CashMultiplier7x" },
	{ multiplier = 12, productKey = "CashMultiplier12x" },
	{ multiplier = 20, productKey = "CashMultiplier20x" },
	{ multiplier = 40, productKey = "CashMultiplier40x" },
} :: { Tier }

CashMultiplierConfig.MaxTier = #CashMultiplierConfig.Tiers

-- 归一化 tier 到合法区间 [0, MaxTier]
function CashMultiplierConfig.clampTier(tier: number?): number
	local t = math.floor(tonumber(tier) or 0)
	return math.clamp(t, 0, CashMultiplierConfig.MaxTier)
end

-- 当前 tier 对应的现金倍率（未购买为 1）
function CashMultiplierConfig.getMultiplier(tier: number?): number
	local t = CashMultiplierConfig.clampTier(tier)
	if t <= 0 then
		return 1
	end
	return CashMultiplierConfig.Tiers[t].multiplier
end

-- 下一个可购买档位的 index；已满级返回 nil
function CashMultiplierConfig.getNextTier(tier: number?): number?
	local t = CashMultiplierConfig.clampTier(tier)
	if t >= CashMultiplierConfig.MaxTier then
		return nil
	end
	return t + 1
end

-- 根据 productKey 反查档位 index；找不到返回 nil
function CashMultiplierConfig.getTierByProductKey(productKey: string): number?
	for index, tier in ipairs(CashMultiplierConfig.Tiers) do
		if tier.productKey == productKey then
			return index
		end
	end
	return nil
end

-- 屏幕按钮文本，如 "x2 Cash"（UI 文本，纯英文）
function CashMultiplierConfig.formatLabel(tier: number): string
	local entry = CashMultiplierConfig.Tiers[CashMultiplierConfig.clampTier(tier)]
	if not entry then
		return ""
	end
	return string.format("x%d Cash", entry.multiplier)
end

return CashMultiplierConfig
