-- 定义一个通用的倒计时函数
function startCountdown(duration, onUpdate, onEnd, stopFlag)
	local timerCoroutine = coroutine.create(function()
		local timeLeft = duration
		onUpdate(timeLeft)
		while timeLeft > 0 do
			task.wait(1)  -- 等待一秒

			timeLeft = timeLeft - 1

			if stopFlag and stopFlag() then
				return  -- 提前结束协程
			end

			-- 调用更新函数，更新UI或执行其他任务
			if onUpdate then
				onUpdate(timeLeft)
			end
		end
		-- 倒计时结束，调用结束回调
		if onEnd then
			onEnd()
		end
	end)
	coroutine.resume(timerCoroutine)
end
return startCountdown
