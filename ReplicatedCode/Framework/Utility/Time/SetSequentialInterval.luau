--!strict

--[[
	Calls a given callback on some specified interval until the
	clear function is called.

	The callback is given deltaTime since the last call completed, along
	with any extra parameters passed to SetSequentialInterval.

	The first callback call is made after intervalSeconds passes,
	i.e. it is not immediate.
	在某个指定的时间间隔内调用给定的回调，直到
	清除函数。

	回调函数将获得自上次调用完成后的 deltaTime，以及传递给 SetSequentialInterval
	以及传递给 SetSequentialInterval 的任何额外参数。

	第一次回调是在 intervalSeconds 过去后进行的、
	也就是说，回调不是立即进行的。
--]]

local function SetSequentialInterval(callback: (number, ...any) -> nil, intervalSeconds: number, ...: any)
	local cleared = false

	local function call(scheduledTime: number, ...: any)
		if cleared then
			return
		end

		local deltaTime = os.clock() - scheduledTime

		callback(deltaTime, ...)

		task.delay(intervalSeconds, call, os.clock(), ...)
	end

	local function clear()
		cleared = true
	end

	task.delay(intervalSeconds, call, os.clock(), ...)

	return clear
end

return SetSequentialInterval
