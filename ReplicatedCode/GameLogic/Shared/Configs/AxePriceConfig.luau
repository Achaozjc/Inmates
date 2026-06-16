--!strict

--[[
	斧子购买定价（端共享）。

	单价随玩家累计拥有斧子数（ownedAxeCount，只增不减）动态上涨：
		unit = BASE_PRICE + GROWTH * ownedAxeCount
	买 N 把总价 = N × 单价（同一 ownedAxeCount，不逐把递增）。

	价格统一向下取整，保证「显示价」与「实际扣费」一致。
]]

local AxePriceConfig = {}

AxePriceConfig.BASE_PRICE = 5 -- 基础单价
AxePriceConfig.GROWTH = 1 -- 每拥有一把斧子的单价增量
AxePriceConfig.MAX_AXES = 100 -- 斧子总数上限（与 100 槽位一致）
AxePriceConfig.Bundles = { 1, 5, 25, 100 } -- 可购买的批量规格（对应 BuyAxe_N 按钮）
AxePriceConfig.AUTO_MERGE_BUNDLE_SIZE = 100 -- 购买该批量后自动链式合成

-- 当前单价
function AxePriceConfig.getUnitPrice(ownedAxeCount: number): number
	return AxePriceConfig.BASE_PRICE + AxePriceConfig.GROWTH * ownedAxeCount
end

-- 购买 count 把的总价（向下取整）
function AxePriceConfig.getBundlePrice(ownedAxeCount: number, count: number): number
	return math.floor(AxePriceConfig.getUnitPrice(ownedAxeCount) * count)
end

return AxePriceConfig
