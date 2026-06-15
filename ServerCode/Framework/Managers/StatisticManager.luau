local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")


local PlayerDataKey = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.PlayerDataKey)
local PlayerDataServer = require(ServerScriptService.ServerCode.Framework.DataStore.PlayerData.PlayerDataServer)

local StatisticKeys = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.StatisticKeys)
local StatisticTypeCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.StatisticTypeCategory)


local StatisticManager = {}

--========================================

-- 兼容旧档或异常档：统计根表缺失时补空表，避免下游索引报错
local function _ensureStatisticRoot(statistic: {[string]: any}?): {[string]: any}
	if type(statistic) ~= "table" then
		return {}
	end
	return statistic
end

-- 兼容旧档：分组缺失时补空表
local function _ensureStatisticType(statistic: {[string]: any}, statisticType: StatisticTypeCategory.EnumType): {[string]: any}
	if type(statistic[statisticType]) ~= "table" then
		statistic[statisticType] = {}
	end
	return statistic[statisticType]
end

local function _updateStatistic(player: Player, statisticKeys: {[StatisticKeys.EnumType] :number}, operation: (number, number) -> number)
	-- 统一短路：存档未加载时不写统计，避免刷 PlayerDataServer 的未加载告警
	if not PlayerDataServer.hasLoaded(player) then
		--warn(string.format("[StatisticManager] drop write before data loaded: player=%s", player.Name))
		return
	end
	PlayerDataServer.updateValue(player, PlayerDataKey.Statistic, function(Statistic)
		Statistic = _ensureStatisticRoot(Statistic)
		for statisticType, _ in pairs(StatisticTypeCategory) do
			local bucket = _ensureStatisticType(Statistic, statisticType)
			for statisticKey, value in pairs(statisticKeys) do
				local current = bucket[statisticKey] or 0
				bucket[statisticKey] = operation(current, value)
			end
		end
		return Statistic
	end)
end

function StatisticManager.add(player :Player, statisticKeys: {[StatisticKeys.EnumType] :number})  --累计为
	-- 过滤掉 0 值（加 0 是无效操作，不必触发写入）
	local filtered: {[StatisticKeys.EnumType]: number} = {}
	for k, v in pairs(statisticKeys) do
		if v > 0 then
			filtered[k] = v
		end
	end
	if next(filtered) == nil then return end
	_updateStatistic(player, filtered, function(current, value)
		return current + value
	end)
end

function StatisticManager.set(player :Player, statisticKeys: {[StatisticKeys.EnumType] :number})  --设置为
	_updateStatistic(player, statisticKeys, function(current, value)
		return value
	end)
end

function StatisticManager.get(player :Player, statisticType : StatisticTypeCategory.EnumType ,statisticKey: StatisticKeys.EnumType , Statistic:{[string]:any}?)
	-- 读路径也要兜底：未加载期间按 0 返回，避免上层逻辑和日志噪声
	if not Statistic and not PlayerDataServer.hasLoaded(player) then
		return 0
	end
	local statistic = _ensureStatisticRoot(Statistic or PlayerDataServer.getValue(player, PlayerDataKey.Statistic))
	local bucket = _ensureStatisticType(statistic, statisticType)
	if bucket[statisticKey] == nil then
		bucket[statisticKey] = 0
	end
	return bucket[statisticKey]
end

function StatisticManager.reset(player :Player, statisticType : StatisticTypeCategory.EnumType | any) --清空
	if not PlayerDataServer.hasLoaded(player) then
		warn(string.format("[StatisticManager] drop reset before data loaded: player=%s type=%s", player.Name, tostring(statisticType)))
		return
	end
	PlayerDataServer.updateValue(player, PlayerDataKey.Statistic, function(Statistic)	
		Statistic = _ensureStatisticRoot(Statistic)
		if Statistic[statisticType] then
			Statistic[statisticType] = {}
		end
		return Statistic
	end)	
end


return StatisticManager
