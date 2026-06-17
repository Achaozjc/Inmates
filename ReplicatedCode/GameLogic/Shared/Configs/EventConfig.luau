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
		name = "Update 2",
		eventId = "6050060078436975212",
		done = true,
		des = [[

New Brainrots!
New Houses!
New Items!
Stay tuned for the next major update!

]],
	},
	["2"] = {
		name = "Admin Abuse!",
		eventId = "5783418750535598747",
		done = true,
		des = [[

The 2nd ADMIN ABUSE! Stay tuned!

]],
	},
	["15"] = {
		name = "Update 9",
		eventId = "5222895159557096049",
		done = false,
		des = [[

NEW SUMMER BEACH PARTY EVENT HOUSE!
10 NEW SUMMER BEACH PARTY BRAINROTS!
New Summer brainrots every month!
Stay tuned for next weeks udpate!

]],
	},
	["16"] = {
		name = "Admin Abuse!",
		eventId = "2403814192810427004",
		done = false,
		des = [[

Get ready for a new round of Admin Abuse with new events!

]],
	},
	["17"] = {
		name = "Update 10",
		eventId = "7677021055671730801",
		done = false,
		des = [[

Stay tuned for more information!

]],
	},
	["18"] = {
		name = "Admin Abuse!",
		eventId = "2473418776406786646",
		done = false,
		des = [[

Get ready for a new round of Admin Abuse with new events!

]],
	},
} :: { [string]: EventEntry }

return EventConfig
