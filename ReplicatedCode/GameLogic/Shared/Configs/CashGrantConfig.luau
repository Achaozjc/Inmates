--!strict

--[[
	付费金钱档位（端共享）。

	玩家通过 HUD 左侧 PayCash 面板逐档付费，付费后立即获得现金：
		发放额 = 档位倍率 × 当前拥有斧头数（AxeTycoon.ownedAxeCount）。

	属可重复购买的消耗型开发者商品（非永久档位、无持久化状态），每次付费即时结算入 Cash。
	三档倍率 200 / 3000 / 300000（设计价 15 / 119 / 799 Robux）。
	付费注册见 registerDevProducts，发放见 CashGrantService，购买入口见 HUD。
]]

export type Tier = {
	multiplier: number,
	productKey: string, -- 对应 StoreIdCategory.Product 中的键
	floor: number, -- 保底发放额：拥有斧头数为 0 时至少发放此值
}

local CashGrantConfig = {}

-- 与 HUD PayCash 面板自上而下展示顺序一致；index 即档位序号
CashGrantConfig.Tiers = {
	{ multiplier = 200, productKey = "PayCash200", floor = 1000 },
	{ multiplier = 3000, productKey = "PayCash3000", floor = 15000 },
	{ multiplier = 300000, productKey = "PayCash300000", floor = 150000 },
} :: { Tier }

-- 计算某档位的发放现金：倍率 × 拥有斧头数（向下取整，至少为 0），并应用保底值。档位非法返回 0。
function CashGrantConfig.getReward(tierIndex: number, ownedAxeCount: number?): number
	local tier = CashGrantConfig.Tiers[tierIndex]
	if not tier then
		return 0
	end
	local owned = math.max(math.floor(tonumber(ownedAxeCount) or 0), 0)
	return math.max(tier.multiplier * owned, tier.floor)
end

return CashGrantConfig
