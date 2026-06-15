--!strict
-- 排行榜领奖辅助函数（server / client 共享，避免双端重复实现谓词）

local LeaderboardClaim = {}

-- LeaderboardClaim 数据结构：
--   claim[boardId][periodId] = {
--     rank      : number   -- 玩家该周期的排名
--     claimed   : boolean  -- 是否已领取
--     expiresAt : number   -- 过期时间戳（unix 秒），超时后不可领取
--     snapshotAt: number   -- 快照写入时间戳
--   }

type ClaimEntry = { rank: number, claimed: boolean, expiresAt: number, snapshotAt: number }
type ClaimMap = { [string]: { [string]: ClaimEntry } }

-- 检查是否存在任何可领取（未领且未过期）的周奖励
function LeaderboardClaim.hasAnyUnclaimed(claim: ClaimMap, now: number): boolean
	for _, periods in pairs(claim) do
		for _, entry in pairs(periods) do
			if not entry.claimed and entry.expiresAt > now then
				return true
			end
		end
	end
	return false
end

-- 检查指定 board 是否有可领取奖励
function LeaderboardClaim.hasUnclaimedFor(claim: ClaimMap, boardId: string, now: number): boolean
	local periods = claim[boardId]
	if not periods then
		return false
	end
	for _, entry in pairs(periods) do
		if not entry.claimed and entry.expiresAt > now then
			return true
		end
	end
	return false
end

-- 取指定 board 最新的未领取、未过期 periodId（多个时取 expiresAt 最大的）
function LeaderboardClaim.getLatestUnclaimedPeriod(claim: ClaimMap, boardId: string, now: number): (string?, ClaimEntry?)
	local periods = claim[boardId]
	if not periods then
		return nil, nil
	end
	local bestId: string? = nil
	local bestEntry: ClaimEntry? = nil
	for periodId, entry in pairs(periods) do
		if not entry.claimed and entry.expiresAt > now then
			if bestEntry == nil or entry.expiresAt > bestEntry.expiresAt then
				bestId = periodId
				bestEntry = entry
			end
		end
	end
	return bestId, bestEntry
end

return LeaderboardClaim
