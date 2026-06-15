--!strict

export type EnumType = string

local OrderedStoreNames = {
	Axes = "Axes" :: "Axes", -- 总斧子数（AxeTycoon.ownedAxeCount）
	Cash = "Cash" :: "Cash", -- 总 Cash（累计赚取 Statistic.all.earn_cash）
	PlayTime = "PlayTime" :: "PlayTime", -- 总在线时长（Statistic.all.online 分钟）
}

return OrderedStoreNames
