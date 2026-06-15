--!strict

--[[
	排行榜配置（client / server 共享，纯数据，不得 require 服务端模块）。

	每个 board：
	  name        : UI 显示名（纯英文）
	  order       : 展示排序（小在前）
	  metricKind  : 分值规范化 / 展示格式（见 LeaderboardTypes.MetricKind）
	  persistence : 存档周期（终身 / 月 / 赛季，决定 OrderedDataStore 库名 stem）
	  source      : 服务端取值来源描述符（由 LeaderboardService 解释）：
	                  { kind = "playerData", path = {...} } —— 按路径读玩家存档字段
	                  { kind = "statistic", statisticType = ..., dataKey = ... } —— 读 Statistic
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OrderedStoreNames = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.OrderedStoreNames)
local StatisticKeys = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.StatisticKeys)
local StatisticTypeCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.StatisticTypeCategory)
local LeaderboardTypes = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Leaderboard.LeaderboardTypes)

local LeaderboardConfig = {}

LeaderboardConfig.Boards = {
	-- 总斧子数：累计拥有斧头数（只增不减，存于 AxeTycoon.ownedAxeCount）
	[OrderedStoreNames.Axes] = {
		name = "Total Axes",
		order = 1,
		metricKind = LeaderboardTypes.MetricKind.Integer,
		persistence = { kind = LeaderboardTypes.PersistenceKind.Lifetime },
		source = { kind = "playerData", path = { "AxeTycoon", "ownedAxeCount" } },
	},
	-- 总 Cash：累计赚取现金（Statistic.all.earn_cash，PlayerService.addCash 已统计）
	[OrderedStoreNames.Cash] = {
		name = "Total Cash",
		order = 2,
		metricKind = LeaderboardTypes.MetricKind.Currency,
		persistence = { kind = LeaderboardTypes.PersistenceKind.Lifetime },
		source = { kind = "statistic", statisticType = StatisticTypeCategory.all, dataKey = StatisticKeys.earn_cash },
	},
	-- 总在线时长：累计在线分钟数（Statistic.all.online，PlayerService 每分钟 +1）
	[OrderedStoreNames.PlayTime] = {
		name = "Play Time",
		order = 3,
		metricKind = LeaderboardTypes.MetricKind.DurationMinutes,
		persistence = { kind = LeaderboardTypes.PersistenceKind.Lifetime },
		source = { kind = "statistic", statisticType = StatisticTypeCategory.all, dataKey = StatisticKeys.online },
	},
}

function LeaderboardConfig.getBoard(boardId: string)
	return LeaderboardConfig.Boards[boardId]
end

-- 按 order 升序返回 { boardId, config } 列表（UI / 服务端遍历用，遍历顺序稳定）
function LeaderboardConfig.getOrderedBoards(): { { boardId: string, config: any } }
	local list = {}
	for boardId, config in pairs(LeaderboardConfig.Boards) do
		table.insert(list, { boardId = boardId, config = config })
	end
	table.sort(list, function(a, b)
		return (a.config.order or 0) < (b.config.order or 0)
	end)
	return list
end

return LeaderboardConfig
