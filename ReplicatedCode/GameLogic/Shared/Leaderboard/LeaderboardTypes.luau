--!strict
-- 排行榜度量与存档周期类型（配置层共用，便于终身 / 月榜 / 赛季扩展）

local LeaderboardTypes = {}

-- 度量类型：决定 OrderedDataStore 写入规范化与 UI 展示
LeaderboardTypes.MetricKind = {
	Currency = "currency",
	Integer = "integer",
	DurationMinutes = "duration_minutes",
}

-- 存档周期：决定 OrderedDataStore 库名 stem（终身不加后缀；月/赛季加后缀避免混榜）
LeaderboardTypes.PersistenceKind = {
	Lifetime = "lifetime",
	Weekly = "weekly",
	Monthly = "monthly",
	Season = "season",
}

export type PersistenceConfig = { kind: "lifetime" } | { kind: "weekly", periodId: string? } | { kind: "monthly", periodId: string? } | { kind: "season", seasonId: string }

return LeaderboardTypes
