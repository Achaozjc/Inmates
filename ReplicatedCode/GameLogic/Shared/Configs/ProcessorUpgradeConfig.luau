--!strict

--[[
	处理机升级与产能（端共享）。

	每秒加工件数：getRate(u) = floor(1 + Σ_{k=0}^{u-1}(2 + k²/4.5))（向下取整为整数）
	单次升级增益展示：getBoost(u) = getRate(u + 1) - getRate(u)（取整后的实际增量）
	升级价格：getUpgradeCost(u) = floor(6 × 1.33^u)（u 为当前已升级次数）
	价格与 Billboard / 扣费一致，避免 UI 显示整数但实际带小数导致无法购买。
]]

local ProcessorUpgradeConfig = {}

function ProcessorUpgradeConfig.getRate(upgradeCount: number): number
	local count = math.max(0, math.floor(upgradeCount))
	local sum = 0
	for k = 0, count - 1 do
		sum += 2 + (k * k) / 4.5
	end
	return math.floor(1 + sum)
end

function ProcessorUpgradeConfig.getBoost(upgradeCount: number): number
	local count = math.max(0, math.floor(upgradeCount))
	return ProcessorUpgradeConfig.getRate(count + 1) - ProcessorUpgradeConfig.getRate(count)
end

function ProcessorUpgradeConfig.getUpgradeCost(upgradeCount: number): number
	local count = math.max(0, math.floor(upgradeCount))
	return math.floor(6 * (1.33 ^ count))
end

return ProcessorUpgradeConfig
