--!strict

--[[
	Experience Event 面板配置（移植自 dingdong EventEnum）。
	events：左侧列表条目；预约奖励见 getReward（max(500, 50×ownedAxeCount) Cash）。
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CashKey = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.CashKey)
local PlayerDataKey = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.PlayerDataKey)

export type EventEntry = {
	name: string,
	eventId: string,
	done: boolean,
	des: string?,
}

local EventConfig = {}

-- 预约/关注活动奖励：max(MIN_REWARD, PER_AXE × 累计拥有斧头数 ownedAxeCount)
EventConfig.PER_AXE = 50
EventConfig.MIN_REWARD = 500

function EventConfig.getReward(ownedAxeCount: number?): number
	local owned = math.max(math.floor(tonumber(ownedAxeCount) or 0), 0)
	return math.max(EventConfig.PER_AXE * owned, EventConfig.MIN_REWARD)
end

-- 构建服务端发放条目
function EventConfig.buildRewardEntries(ownedAxeCount: number?): { { category: string, itemKey: string, value: number } }
	return {
		{
			category = PlayerDataKey.Currency,
			itemKey = CashKey.Cash,
			value = EventConfig.getReward(ownedAxeCount),
		},
	}
end

-- key 为列表排序用字符串；done=true 归入 Update 区，否则在 Event 区
EventConfig.events = {
	["1"] = {
		name = "Update 1",
		eventId = "3595773247188238927",
		done = false,
		des = [[

👮👮👮Stay tuned for update 1!👮👮👮👮

]],
	},
	["2"] = {
		name = "Update 2",
		eventId = "6913022917932614295",
		done = false,
		des = [[

👮👮👮Stay tuned for update 2!👮👮👮👮

]],
	},
	["3"] = {
		name = "Update 3",
		eventId = "3248619768026104422",
		done = false,
		des = [[

👮👮👮Stay tuned for update 3!👮👮👮👮


]],
	}

} :: { [string]: EventEntry }

return EventConfig
