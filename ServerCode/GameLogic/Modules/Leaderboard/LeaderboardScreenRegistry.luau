--!strict
-- 各 LeaderboardScreen Binder 组件在此注册缓存，供展示屏与奖励服务按需读取 Top 100

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.ReplicatedCode.Framework.Packages.Signal)

type Entry = {
	entries: { { key: string, value: number } },
	fetchedAt: number,
	periodId: string?,
}

local registry: { [string]: Entry } = {}
local updated = Signal.new()
local LeaderboardScreenRegistry = {}

-- LeaderboardService 在刷新缓存后调用此函数，并通知所有展示屏
function LeaderboardScreenRegistry.update(boardId: string, entries: { { key: string, value: number } }, periodId: string?)
	registry[boardId] = {
		entries = entries,
		fetchedAt = os.time(),
		periodId = periodId,
	}
	updated:Fire(boardId, entries)
end

function LeaderboardScreenRegistry.onUpdated(callback: (boardId: string, entries: { { key: string, value: number } }) -> ()): Signal.SignalConnection
	return updated:Connect(callback)
end

function LeaderboardScreenRegistry.getCached(boardId: string): Entry?
	return registry[boardId]
end

-- 按 userId 在缓存 entries 里查找排名（1-based），key 格式为 "name_userId"
function LeaderboardScreenRegistry.getViewerRank(boardId: string, userId: number): number?
	local cached = registry[boardId]
	if not cached then
		return nil
	end
	local suffix = "_" .. tostring(userId)
	for i, entry in ipairs(cached.entries) do
		if string.sub(entry.key, -#suffix) == suffix then
			return i
		end
	end
	return nil
end

return LeaderboardScreenRegistry
