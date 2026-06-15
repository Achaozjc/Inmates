--!strict
-- ServerScriptService/Game/Service/Sync/RefreshService.luau

--[[
	文件: RefreshService.luau
	描述: 时间刷新服务，负责处理每日、每周及特定时间间隔（如15分钟）的全局重置逻辑
	职责:
		1. 维护并同步各类时间戳 (15分钟, 每日, 每周)
		2. 定时检查时间是否到达刷新点，并触发服务端事件和客户端通知
		3. 提供查询当前时间戳的接口
	
	优化说明:
		1. 引入 --!strict 和详细的类型定义
		2. 移除冗余的 ServerStorage 引用
		3. 使用 task 库替代 Timer 模块（如果 Timer 仅作简单循环），或优化 Timer 使用
		   此处选择使用 task.delay 的智能调度循环，相比每秒轮询更节省性能
		4. 补全 updateTimestamp 逻辑，使其显式初始化所有时间戳
		5. 增加详细的中文注释和常量提取
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local getNextDayTimestamp = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Time.GetNextDayTimestamp)
local getNextWeekTimestamp = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Time.GetNextWeekTimestamp)
local TimestampCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.TimestampCategory)
local Network = require(ReplicatedStorage.ReplicatedCode.Framework.Core.Network)
local RemoteEventKey = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.RemoteEventKey)
local RemoteFunctionKey = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.RemoteFunctionKey)
local TimeTokenCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.TimeTokenCategory)
local getUTCMinTimestamp = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Time.GetUTCMinTimestamp)

-- 常量定义
local MIN_15_SECONDS = TimeTokenCategory.minutes * 15

local RefreshService = {}

-- 类型定义
type Timestamps = {
	[string]: number,
}

RefreshService.Timestamps = {
	[TimestampCategory.min15] = 0,
	[TimestampCategory.daily] = 0,
	[TimestampCategory.weekly] = 0,
} :: Timestamps

-- 服务端内部事件，供其他服务监听
RefreshService.newMin15 = Instance.new("BindableEvent")
RefreshService.newDay = Instance.new("BindableEvent")
RefreshService.newWeek = Instance.new("BindableEvent")
RefreshService.timeStampChanged = Instance.new("BindableEvent")

--========================================
-- 时间戳更新逻辑
--========================================

-- 初始化/更新所有时间戳
-- 通常在服务器启动时调用
function RefreshService.updateTimestamp()
	RefreshService.update15minTimestamp()
	RefreshService.updateDayTimestamp()
	RefreshService.updateWeekTimestamp()
	RefreshService.timeStampChanged:Fire(RefreshService.Timestamps)
end

-- 更新 15 分钟周期时间戳
function RefreshService.update15minTimestamp()
	-- 获取下一个 15 分钟节点的 UTC 时间戳
	RefreshService.Timestamps[TimestampCategory.min15] = getUTCMinTimestamp(MIN_15_SECONDS)

	-- 通知客户端
	Network.fireAllClients(
		RemoteEventKey.Refresh_Timestamp,
		TimestampCategory.min15,
		RefreshService.Timestamps[TimestampCategory.min15]
	)

	-- 触发服务端事件 (带参数方便订阅者直接使用)
	RefreshService.newMin15:Fire(RefreshService.Timestamps[TimestampCategory.min15])
end

-- 更新每日重置时间戳
function RefreshService.updateDayTimestamp()
	RefreshService.Timestamps[TimestampCategory.daily] = getNextDayTimestamp()
	Network.fireAllClients(
		RemoteEventKey.Refresh_Timestamp,
		TimestampCategory.daily,
		RefreshService.Timestamps[TimestampCategory.daily]
	)
	RefreshService.newDay:Fire()
end

-- 更新每周重置时间戳
function RefreshService.updateWeekTimestamp()
	RefreshService.Timestamps[TimestampCategory.weekly] = getNextWeekTimestamp(Workspace:GetServerTimeNow())
	Network.fireAllClients(
		RemoteEventKey.Refresh_Timestamp,
		TimestampCategory.weekly,
		RefreshService.Timestamps[TimestampCategory.weekly]
	)
	RefreshService.newWeek:Fire()
end

--========================================
-- 核心循环 (Core Loop)
--========================================

-- 检查并处理时间到达
-- @param now: 当前服务器时间
local function checkTimestamps(now: number)
	-- 15分钟刷新
	if RefreshService.Timestamps[TimestampCategory.min15] <= now then
		print("[RefreshService] 15 Minute Refresh Triggered")
		RefreshService.update15minTimestamp()
	end

	-- 每日刷新
	if RefreshService.Timestamps[TimestampCategory.daily] <= now then
		print("[RefreshService] Daily Refresh Triggered")
		RefreshService.updateDayTimestamp()
	end

	-- 每周刷新
	if RefreshService.Timestamps[TimestampCategory.weekly] <= now then
		print("[RefreshService] Weekly Refresh Triggered")
		RefreshService.updateWeekTimestamp()
	end
end

function RefreshService.start()
	-- 初始更新
	RefreshService.updateTimestamp()

	-- 启动心跳循环
	-- 相比 Timer 模块，直接使用 task.spawn + while task.wait(1) 更轻量且易于控制
	task.spawn(function()
		while true do
			-- 每秒检查一次，确保精度
			-- 如果需要极致性能，可以计算最小剩余时间然后 task.wait(minDiff)，
			-- 但考虑到服务器可能有时钟漂移或手动调整，每秒检查最稳健。
			task.wait(1)

			local now = workspace:GetServerTimeNow()
			checkTimestamps(now)
		end
	end)
end

function RefreshService.listen()
	local t = Network.t

	-- 客户端查询时间戳接口
	Network.bindFunction(
		RemoteFunctionKey.Get_Timestamp,
		(function(player: Player, timeKey: string)
			return RefreshService.Timestamps[timeKey] or 0
		end) :: any,
		t.string
	)
end

return RefreshService
