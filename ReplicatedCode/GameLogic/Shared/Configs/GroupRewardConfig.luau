--!strict

--[[
	群组奖励配置（端共享）。

	玩家触碰自己基地 TouchedButtons/Group 时，若已加入游戏群组（GroupId），
	可领取一次现金奖励：
		奖励额 = max(PER_AXE × 当前拥有斧头数, MIN_REWARD)

	即拥有斧头数为 0（或不足）时按 MIN_REWARD 保底发放。每 COOLDOWN 秒可领取一次。

	领取/校验见服务端 GroupRewardService；Billboard（CashAmount/CountDown）显示见
	客户端 GroupRewardBillboardController。下次可领取时间通过玩家属性
	AttributeEnum.GroupRewardReadyAt 复制到客户端用于倒计时。
]]

local GroupRewardConfig = {}

-- 每个斧头折算的奖励现金
GroupRewardConfig.PER_AXE = 75

-- 保底奖励（拥有斧头数为 0 或奖励不足时按此发放）
GroupRewardConfig.MIN_REWARD = 500

-- 领取冷却（秒），10 分钟
GroupRewardConfig.COOLDOWN = 600

-- 计算可领取的奖励现金：PER_AXE × 拥有斧头数，至少 MIN_REWARD（向下取整）
function GroupRewardConfig.getReward(ownedAxeCount: number?): number
	local owned = math.max(math.floor(tonumber(ownedAxeCount) or 0), 0)
	return math.max(GroupRewardConfig.PER_AXE * owned, GroupRewardConfig.MIN_REWARD)
end

return GroupRewardConfig
