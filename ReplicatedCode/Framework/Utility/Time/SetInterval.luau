--!strict

--[[
	在某个指定的时间间隔内调用给定的回调，直到
	函数被调用。

	回调函数的值是自上次调用后的 deltaTime，以及传递给 setInterval
	以及传递给 setInterval 的任何额外参数。

	第一次回调是在 intervalSeconds 时间过后进行的、
	也就是说，回调不是立即进行的。
--]]

local function setInterval(callback: (number, ...any) -> ...any, intervalSeconds: number, ...: any)
	local cleared = false

	local function call(scheduledTime: number, ...: any)
		if cleared then
			return
		end

		local deltaTime = os.clock() - scheduledTime

		task.spawn(callback, deltaTime, ...)

		task.delay(intervalSeconds, call, os.clock(), ...)
	end

	local function clear()
		cleared = true
	end

	task.delay(intervalSeconds, call, os.clock(), ...)

	return clear
end

return setInterval
