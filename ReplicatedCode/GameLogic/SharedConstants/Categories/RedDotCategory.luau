--!strict
--[[
	红点 key 枚举，每个 key 对应一个 MainGui 按钮上的红点状态。
	扩展：新增按钮时在此追加一行，同步在 RedDotConditions.registerAll() 里注册条件。
]]

local RedDotCategory = {
	Index           = "Index",
	SeasonPass      = "SeasonPass",
	SeasonPassQuest = "SeasonPassQuest", -- SeasonPass 面板内 QuestButton 上的红点（任务可领取）
	MenuBoard       = "MenuBoard",
	StoreAd         = "StoreAd",
}

export type RedDotKey = string

return RedDotCategory
