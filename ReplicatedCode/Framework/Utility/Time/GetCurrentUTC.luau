local function getCurrentUTCMin()
	local timestamp = os.time() -- DateTime.now().UnixTimestamp
	return os.date("!*t", timestamp)
end

return getCurrentUTCMin
