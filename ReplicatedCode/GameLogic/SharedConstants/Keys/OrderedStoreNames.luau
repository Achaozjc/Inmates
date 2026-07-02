--!strict

export type EnumType = string

local OrderedStoreNames = {
	Cash = "Cash" :: "Cash", -- 终身 Cash（累计赚取 Statistic.all.earn_cash）
	PlayTime = "PlayTime" :: "PlayTime", -- 在线时长（Statistic.all.online 分钟）
	TotalMerges = "TotalMerges" :: "TotalMerges", -- 总融合次数（Statistic.all.total_merges）
}

return OrderedStoreNames
