--!strict



--[[

	兑换码配置表（客户端展示 + 服务端校验共用）。

	每条 code：

	  voteTarget — 游戏全局 upVotes 解锁门槛（nil 表示上线即可用）

	  rewards    — PlayerService.getRewards 奖励条目

	               固定金额用 cash(amount)

	               按拥有斧头数折算用 cashPerAxe(perAxe)，实际发放 = perAxe × ownedAxeCount

]]



local ReplicatedStorage = game:GetService("ReplicatedStorage")



local CashKey = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.CashKey)

local PlayerDataKey = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.PlayerDataKey)



export type RewardItem = {

	category: string,

	itemKey: string,

	value: number,

	perAxe: number?,

}



export type CodeEntry = {

	voteTarget: number?,

	rewards: { RewardItem },

}



local function cash(amount: number): RewardItem

	return {

		category = PlayerDataKey.Currency,

		itemKey = CashKey.Cash,

		value = amount,

	}

end



local function cashPerAxe(perAxe: number): RewardItem

	return {

		category = PlayerDataKey.Currency,

		itemKey = CashKey.Cash,

		value = 0,

		perAxe = perAxe,

	}

end



local CodeRewardConfig = {}



-- 将配置中的奖励解析为实际发放条目（perAxe 按 ownedAxeCount 折算）

function CodeRewardConfig.resolveRewards(rewards: { RewardItem }, ownedAxeCount: number?): { RewardItem }

	local owned = math.max(math.floor(tonumber(ownedAxeCount) or 0), 0)

	local resolved: { RewardItem } = {}



	for _, reward in ipairs(rewards) do

		local value = tonumber(reward.value) or 0

		if reward.perAxe then

			value = math.floor(reward.perAxe * owned)

		end

		if value > 0 then

			table.insert(resolved, {

				category = reward.category,

				itemKey = reward.itemKey,

				value = value,

			})

		end

	end



	return resolved

end



CodeRewardConfig.Codes = {
	["prisonworkshop"] = {
		voteTarget = nil,
		rewards = {
			cash(30),
		},
	},
	["workworkjobsdone"] = {
		voteTarget = 100,
		rewards = {
			cash(300),
		},
	},
	["allworknoplay"] = {
		voteTarget = 250,
		rewards = {
			cash(500),
		},
	},
	["prisonlife4days"] = {
		voteTarget = 500,
		rewards = {
			cashPerAxe(10),
		},
	},
	["alldayprisoner"] = {
		voteTarget = 1000,
		rewards = {
			cashPerAxe(15),
		},
	},
	["workforcash"] = {
		voteTarget = 2000,
		rewards = {
			cashPerAxe(30),
		},
	},
	["cashoutprison"] = {
		voteTarget = 5000,
		rewards = {
			cashPerAxe(50),
		},
	},
	["bigprisonwarden"] = {
		voteTarget = 10000,
		rewards = {
			cashPerAxe(80),
		},
	},
	["iworkforcash"] = {
		voteTarget = 20000,
		rewards = {
			cashPerAxe(100),
		},
	},
} :: { [string]: CodeEntry }



return CodeRewardConfig

