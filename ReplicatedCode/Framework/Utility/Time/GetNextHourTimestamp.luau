local function getNextHourTimestamp()
	local timestamp = os.time()
	local currentTable = os.date("!*t", timestamp)
	local nextHourTable = {
		year = currentTable.year, 
		month = currentTable.month, 
		day = currentTable.day, 
		hour = currentTable.hour + 1, 
		min = 0 , 
		sec = 0
	}
	local nextHourTimestamp = os.time(nextHourTable)
	return nextHourTimestamp
end

return getNextHourTimestamp
