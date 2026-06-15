-- 返回下一个 UTC 00:00 的时间戳（秒）
local function getNextDayTimestamp(): number
	local now = os.time()
	local t = os.date("!*t", now) :: any
	-- 距离今日 UTC 午夜已过的秒数
	local secondsIntoDay = t.hour * 3600 + t.min * 60 + t.sec
	local nextMidnight = now - secondsIntoDay + 24 * 3600
	return nextMidnight
end

return getNextDayTimestamp
