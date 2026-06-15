--!strict

--[[
	接收任意数量的回调，并并行执行，返回第一个回调的结果。
	如果出现错误，该错误会冒泡上升到主线程。
	当第一个回调返回时，其他回调将使用 task.cancel 取消。

	为异步 lua 回调提供与 Promise.race 类似的功能
--]]

type Callback = () -> ...any

local function waitForFirstAsync(...: Callback)
	local thisThread = coroutine.running()
	local resumed = false
	local errorThrown: any

	local function resume(...: any)
		if resumed then
			return
		end
		resumed = true

		task.spawn(thisThread, ...)
	end

	for _, callback in ipairs({ ... }) do
		task.defer(function()
			-- 我们正在将 pcall 返回的所有值捕获到一个表中，这样我们就可以继续此线程
			-- 如果有多个返回值，则将所有值
			local pcallReturnValues = { pcall(callback) }
			if not pcallReturnValues[1] then
				errorThrown = pcallReturnValues[2]
			end

			resume(table.unpack(pcallReturnValues, 2))
		end)
	end

	local returnValues = { coroutine.yield() }

	if errorThrown then
		-- 返回三个调用者的堆栈跟踪，直到传入 waitForFirstAsync 的函数被
		-- 声明
		error(errorThrown, 3)
	end

	return table.unpack(returnValues)
end

return waitForFirstAsync
