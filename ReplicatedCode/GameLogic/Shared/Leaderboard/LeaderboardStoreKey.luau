--!strict
-- 由榜单配置生成 OrderedDataStore 的 stem（与 GameSetting.DATA_STORE_VERSION 拼成最终库名）

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local getNextWeekTimestamp = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Time.GetNextWeekTimestamp)

local LeaderboardTypes = require(script.Parent.LeaderboardTypes)

type PersistenceConfig = LeaderboardTypes.PersistenceConfig

local LeaderboardStoreKey = {}

local function yyyymmUtc(now: number): string
	return os.date("!%Y%m", now)
end

local function absoluteWeekUtc(now: number): string
	-- 使用项目中统一的周一 UTC 00:00 刷新逻辑（下一周时间戳作为本周的绝对标识）
	return "W" .. tostring(getNextWeekTimestamp(now))
end

-- 根据 boardId（与 OrderedStoreNames / 部件属性一致）与持久化策略生成 stem
function LeaderboardStoreKey.buildDatastoreStem(boardId: string, persistence: PersistenceConfig?, nowUtc: number?): string
	local p = persistence or { kind = LeaderboardTypes.PersistenceKind.Lifetime }
	if p.kind == LeaderboardTypes.PersistenceKind.Lifetime then
		return boardId
	elseif p.kind == LeaderboardTypes.PersistenceKind.Weekly then
		local ts = nowUtc or os.time()
		local period = p.periodId or absoluteWeekUtc(ts)
		return boardId .. "_" .. period
	elseif p.kind == LeaderboardTypes.PersistenceKind.Monthly then
		local ts = nowUtc or os.time()
		local period = p.periodId or yyyymmUtc(ts)
		return boardId .. "_" .. period
	elseif p.kind == LeaderboardTypes.PersistenceKind.Season then
		return boardId .. "_" .. p.seasonId
	end
	return boardId
end

return LeaderboardStoreKey
