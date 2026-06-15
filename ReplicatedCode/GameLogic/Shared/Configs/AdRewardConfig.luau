--!strict

local AdRewardConfig = {}

AdRewardConfig.Rewards = {}

function AdRewardConfig.getReward(rewardKey: string)
	return AdRewardConfig.Rewards[rewardKey]
end

return AdRewardConfig
