--!strict
local pollInterval = 0.05


-- Helper: wait for animation to finish with timeout
local function waitForAnimationEndWithTimeout(animationTrack :AnimationTrack, timeoutSeconds: number)
	if not animationTrack then
		return
	end

	-- 启动播放
	if not animationTrack.IsPlaying then
		animationTrack:Play()
	else
		-- 已经在播放中，直接继续等待
	end

	local startTime = os.clock()
	local waited = 0
	-- 使用较小的时间步长来轮询状态

	while true do
		-- 计算已等待时间
		waited = os.clock() - startTime
		-- 如果动画已结束或不再播放，跳出
		if not animationTrack.IsPlaying then
			break
		end
		-- 超时保护
		if waited >= timeoutSeconds then
			break
		end
		-- 等待一个很短的时间再继续检查
		task.wait(pollInterval)
	end
end


return waitForAnimationEndWithTimeout