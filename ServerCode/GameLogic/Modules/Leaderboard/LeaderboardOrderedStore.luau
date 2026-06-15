--!strict

--[[
	LeaderboardOrderedStore
	单个榜单的 OrderedDataStore 封装（移植自 dingdong 的 OrderedDataStore，适配 axe 工具链）。

	- 库名 = LeaderboardStoreKey.buildDatastoreStem(boardId, persistence) .. "_" .. ORDER_DATA_STORE_VERSION
	  （终身榜 stem 即 boardId；月/赛季榜带周期后缀，避免混榜）
	- key = "玩家名_UserId"（嵌入玩家名，读回时免去额外 GetNameFromUserIdAsync）
	- 写入与读取均走 RetryAsync 指数退避重试
]]

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedLogic = ReplicatedStorage.ReplicatedCode.GameLogic

local GameSetting = require(SharedLogic.Shared.Settings.GameSetting)
local RichTextCategory = require(SharedLogic.SharedConstants.Categories.RichTextCategory)
local LeaderboardStoreKey = require(SharedLogic.Shared.Leaderboard.LeaderboardStoreKey)
local retryAsync = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Common.RetryAsync)

local DISPLAY_COUNT = 100
local MAX_ATTEMPTS = 3
local RETRY_PAUSE_CONSTANT = 1
local RETRY_PAUSE_EXPONENT = 2

export type StoreEntry = { key: string, value: number }

local LeaderboardOrderedStore = {}
LeaderboardOrderedStore.__index = LeaderboardOrderedStore

export type ClassType = typeof(setmetatable(
	{} :: {
		_boardId: string,
		_storeKey: string,
		_dataStore: OrderedDataStore,
	},
	LeaderboardOrderedStore
))

function LeaderboardOrderedStore.new(boardId: string, persistence: any?): ClassType
	local self = setmetatable({}, LeaderboardOrderedStore)
	self._boardId = boardId

	local stem = LeaderboardStoreKey.buildDatastoreStem(boardId, persistence)
	self._storeKey = string.format(RichTextCategory._connnect, stem, GameSetting.ORDER_DATA_STORE_VERSION)
	self._dataStore = DataStoreService:GetOrderedDataStore(self._storeKey)

	return self
end

-- 写入玩家分值（score 必须为非负整数，调用方负责规范化）
function LeaderboardOrderedStore.setAsync(self: ClassType, player: Player, score: number): boolean
	local key = string.format(RichTextCategory._connnect, player.Name, player.UserId)
	local success, err = retryAsync(function()
		self._dataStore:SetAsync(key, score)
	end, MAX_ATTEMPTS, RETRY_PAUSE_CONSTANT, RETRY_PAUSE_EXPONENT)

	if not success then
		warn(string.format("[LeaderboardOrderedStore] setAsync failed board=%s player=%d: %s", self._boardId, player.UserId, tostring(err)))
	end
	return success
end

-- 读取 Top N（降序），返回 { {key=玩家名_UserId, value=分值}, ... }
function LeaderboardOrderedStore.getSortedAsync(self: ClassType, count: number?): { StoreEntry }?
	local target = math.min(count or DISPLAY_COUNT, DISPLAY_COUNT)
	local success, result = retryAsync(function()
		-- DataStorePages 单页上限 100
		return self._dataStore:GetSortedAsync(false, math.min(target, 100))
	end, MAX_ATTEMPTS, RETRY_PAUSE_CONSTANT, RETRY_PAUSE_EXPONENT)

	if not success then
		warn(string.format("[LeaderboardOrderedStore] getSortedAsync failed board=%s: %s", self._boardId, tostring(result)))
		return nil
	end

	local pages = result :: DataStorePages
	local entries: { StoreEntry } = {}

	repeat
		for _, data in pages:GetCurrentPage() do
			table.insert(entries, { key = data.key, value = data.value })
		end
		if pages.IsFinished then
			break
		else
			pages:AdvanceToNextPageAsync()
		end
	until #entries >= target

	return entries
end

return LeaderboardOrderedStore
