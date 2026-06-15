local function getWeekOfYearFromTimestamp()
	local timestamp = os.time()
	-- 获取该时间戳对应的日期
	local dateTable = os.date("*t", timestamp)

	-- 获取这一年的第一天
	local firstDayOfYear = os.time{year=dateTable.year, month=1, day=1}

	-- 获取这一年第一周的星期几
	local firstDayOfWeek = os.date("*t", firstDayOfYear).wday

	-- 计算过去的天数
	local dayOfYear = os.date("%j", timestamp)

	-- 计算已经过的周数（仍然需要处理开始的偏移，考虑到第一天的星期几）
	local pastDaysFromFirstWeek = dayOfYear + (firstDayOfWeek - 1)
	local weekNumber = math.floor(pastDaysFromFirstWeek / 7)

	return weekNumber
end

return getWeekOfYearFromTimestamp
