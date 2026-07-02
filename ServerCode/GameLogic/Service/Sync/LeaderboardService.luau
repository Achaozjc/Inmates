--!strict

--[[
	LeaderboardService（服务端权威）
	移植自 dingdong 的 LeaderboardScreen 编排逻辑，仅做后端数据层：
	  1. 周期性将在线玩家的各榜单分值写入对应 OrderedDataStore；
	  2. 读回 Top100 并缓存（含玩家名 / UserId / 展示字符串）；
	  3. 通过 RemoteFunction(GetLeaderboard) 暴露给客户端拉取。

	榜单注册见 LeaderboardConfig（Lifetime Cash / Playtime / Total Merges）。展示层由 LeaderboardScreen 组件负责。
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SharedLogic = ReplicatedStorage.ReplicatedCode.GameLogic
local ServerCode = ServerScriptService.ServerCode

local Network = require(ReplicatedStorage.ReplicatedCode.Framework.Core.Network)
local ThreadQueue = require(ReplicatedStorage.ReplicatedCode.Framework.Infrastructure.Classes.ThreadQueue)
local setInterval = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Time.SetInterval)

local GameSetting = require(SharedLogic.Shared.Settings.GameSetting)
local RemoteFunctionKey = require(SharedLogic.SharedConstants.Keys.RemoteFunctionKey)
local LeaderboardConfig = require(SharedLogic.Shared.Configs.LeaderboardConfig)
local LeaderboardScore = require(SharedLogic.Shared.Leaderboard.LeaderboardScore)

local PlayerDataServer = require(ServerCode.Framework.DataStore.PlayerData.PlayerDataServer)
local StatisticManager = require(ServerCode.Framework.Managers.StatisticManager)
local LeaderboardOrderedStore = require(ServerCode.GameLogic.Modules.Leaderboard.LeaderboardOrderedStore)
local LeaderboardScreenRegistry = require(ServerCode.GameLogic.Modules.Leaderboard.LeaderboardScreenRegistry)
local LeaderboardIgnore = require(ServerCode.GameLogic.DataStore.LeaderboardIgnore)

local DISPLAY_COUNT = 100

type Entry = { rank: number, userId: number, name: string, score: number, displayValue: string }

local LeaderboardService = {}

-- 模块级状态（服务为单例，无 OOP 实例）
local stores: { [string]: LeaderboardOrderedStore.ClassType } = {}
local caches: { [string]: { Entry } } = {}
local updateQueue: ThreadQueue.ClassType
local intervalCleanup: (() -> ())?
local started = false

-- 按 board.source 描述符解析玩家的原始分值（不做规范化）
local function resolveRawValue(player: Player, config: any): number
	local source = config.source
	if type(source) ~= "table" then
		return 0
	end

	if source.kind == "statistic" then
		return StatisticManager.get(player, source.statisticType, source.dataKey) or 0
	elseif source.kind == "playerData" then
		local path = source.path
		if type(path) ~= "table" or #path == 0 then
			return 0
		end
		local current: any = PlayerDataServer.getValue(player, path[1])
		for i = 2, #path do
			if type(current) ~= "table" then
				return 0
			end
			current = current[path[i]]
		end
		return tonumber(current) or 0
	end

	return 0
end

-- 将 OrderedDataStore 读回的原始条目解析为展示用 Entry 列表
local function buildEntries(boardId: string, sorted: { LeaderboardOrderedStore.StoreEntry }): { Entry }
	local config = LeaderboardConfig.getBoard(boardId)
	local entries: { Entry } = {}
	for rank, data in ipairs(sorted) do
		-- key = "玩家名_UserId"，贪婪匹配最后一个下划线（兼容名字含下划线）
		local playerName, userIdStr = string.match(data.key, "(.+)_(.+)")
		local userId = tonumber(userIdStr)
		if playerName and userId then
			table.insert(entries, {
				rank = rank,
				userId = userId,
				name = playerName,
				score = data.value,
				displayValue = LeaderboardScore.formatDisplayValue(data.value, config.metricKind),
			})
		end
	end
	return entries
end

-- 将缓存条目转为展示屏所需的 { key, value } 格式
local function entriesToRegistryPayload(entries: { Entry }): { { key: string, value: number } }
	local payload: { { key: string, value: number } } = {}
	for _, entry in ipairs(entries) do
		table.insert(payload, {
			key = string.format("%s_%d", entry.name, entry.userId),
			value = entry.score,
		})
	end
	return payload
end

-- 刷新单个榜单：写入在线玩家分值 → 读回 Top100 → 更新缓存
local function updateBoardAsync(boardId: string)
	local store = stores[boardId]
	local config = LeaderboardConfig.getBoard(boardId)
	if not store or not config then
		return
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if LeaderboardIgnore.ignore(player.UserId) then
			continue -- 忽略开发者 / 负 UserId
		end
		if not PlayerDataServer.hasLoaded(player) then
			continue
		end

		local raw = resolveRawValue(player, config)
		if raw > 0 then
			local score = LeaderboardScore.toOrderedStoreScore(raw, config.metricKind)
			if score > 0 then
				task.spawn(function()
					updateQueue:submitAsync(function()
						store:setAsync(player, score)
					end)
				end)
			end
		end
	end

	local success, sorted = updateQueue:submitAsync(function()
		return store:getSortedAsync(DISPLAY_COUNT)
	end)

	if success and sorted then
		caches[boardId] = buildEntries(boardId, sorted)
		LeaderboardScreenRegistry.update(boardId, entriesToRegistryPayload(caches[boardId]))
	end
end

local function updateAllBoards()
	for _, item in ipairs(LeaderboardConfig.getOrderedBoards()) do
		task.spawn(updateBoardAsync, item.boardId)
	end
end

-- 组装单个榜单的对外快照（meta + 缓存条目）
local function snapshotBoard(boardId: string)
	local config = LeaderboardConfig.getBoard(boardId)
	if not config then
		return nil
	end
	return {
		boardId = boardId,
		name = config.name,
		metricKind = config.metricKind,
		order = config.order,
		entries = caches[boardId] or {},
	}
end

-- RemoteFunction 回调：boardId 为 nil 时返回全部榜单（按 order 升序），否则返回单个
local function onGetLeaderboard(_player: Player, boardId: string?)
	if typeof(boardId) == "string" then
		return snapshotBoard(boardId)
	end

	local result = {}
	for _, item in ipairs(LeaderboardConfig.getOrderedBoards()) do
		table.insert(result, snapshotBoard(item.boardId))
	end
	return result
end

function LeaderboardService.start()
	if started then
		return
	end
	started = true

	-- 并发队列：节流 OrderedDataStore 读写（参数对齐 dingdong）
	updateQueue = ThreadQueue.new(5, 100, true)

	for _, item in ipairs(LeaderboardConfig.getOrderedBoards()) do
		stores[item.boardId] = LeaderboardOrderedStore.new(item.boardId, item.config.persistence)
		caches[item.boardId] = {}
	end

	-- 首次立即刷新一遍，随后按间隔周期刷新
	task.spawn(updateAllBoards)
	intervalCleanup = setInterval(updateAllBoards, GameSetting.LEADERBOARD_UPDATE_INTERVAL)
end

function LeaderboardService.listen()
	Network.bindFunction(RemoteFunctionKey.GetLeaderboard, onGetLeaderboard)
end

return LeaderboardService
