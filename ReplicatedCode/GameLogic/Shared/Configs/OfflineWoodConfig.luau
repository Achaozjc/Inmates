--!strict

--[[
	离线木料配置（服务端结算 / 客户端展示共享）。

	玩家离线期间按「累计拥有斧头数 ownedAxeCount」累积离线木料：
		每离线 1 分钟收益 = PER_MINUTE_PER_AXE × ownedAxeCount
		上限            = CAP_PER_AXE × ownedAxeCount
	木料按 1:1 进入处理机库存（1 木料 = 1 现金价值）。
]]

local OfflineWoodConfig = {}

-- 每离线 1 分钟、每把斧子产出的离线木料
OfflineWoodConfig.PER_MINUTE_PER_AXE = 0.4
-- 每把斧子累积的离线木料上限（达到约 PER/ CAP = 500 分钟封顶）
OfflineWoodConfig.CAP_PER_AXE = 200

-- 据离线秒数与拥有斧头数结算本次应得离线木料（向下取整，封顶）
function OfflineWoodConfig.compute(ownedAxeCount: number, offlineSeconds: number): number
	if ownedAxeCount <= 0 or offlineSeconds <= 0 then
		return 0
	end

	local minutes = offlineSeconds / 60
	local raw = OfflineWoodConfig.PER_MINUTE_PER_AXE * minutes * ownedAxeCount
	local cap = OfflineWoodConfig.CAP_PER_AXE * ownedAxeCount
	return math.floor(math.min(raw, cap))
end

return OfflineWoodConfig
