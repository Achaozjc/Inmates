--!strict

export type EnumType = string

local StatisticKeys = {
	online = "online" :: "online",
	earn_cash = "earn_cash" :: "earn_cash",
	spend_cash = "spend_cash" :: "spend_cash",
	spend_robux = "spend_robux" :: "spend_robux",
	exp = "exp" :: "exp",
	signs = "signs" :: "signs",
	streak_signs = "streak_signs" :: "streak_signs",
	max_streak_signs = "max_streak_signs" :: "max_streak_signs",
	lastweek_signs = "lastweek_signs" :: "lastweek_signs",
	complete_alldaily = "complete_alldaily" :: "complete_alldaily",
	complete_allweekly = "complete_allweekly" :: "complete_allweekly",
	collect = "collect" :: "collect",
	collect_ = "collect_%s" :: "collect_%s",
	sold = "sold" :: "sold",
	lv = "lv" :: "lv",
	lucky = "lucky" :: "lucky",
	total_merges = "total_merges" :: "total_merges",
}

return StatisticKeys
