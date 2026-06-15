-- 返回严格晚于 now 的「下一个周一 UTC 00:00」时间戳（秒）
-- 原逻辑在周一白天会算成「本周一 0 点」导致时间戳已过期，进而周统计/通行证周任务无法与服务器周期对齐、UI 倒计时为空
-- wday: 周日=1, 周一=2, ..., 周六=7
local function getNextWeekTimestamp(now: number?): number
	-- GetServerTimeNow 可能带亚秒小数，与 DataStore/JSON 整秒时间戳混用会产生脏比较
	local t0 = math.floor((now or os.time()) :: number)
	local t = os.date("!*t", t0) :: any
	local secondsIntoDay = t.hour * 3600 + t.min * 60 + t.sec
	local todayMidnight = t0 - secondsIntoDay

	local daysUntilMonday = (9 - t.wday) % 7
	local nextMonday = todayMidnight + daysUntilMonday * 24 * 3600
	while nextMonday <= t0 do
		nextMonday += 7 * 24 * 3600
	end
	return nextMonday
end

return getNextWeekTimestamp
