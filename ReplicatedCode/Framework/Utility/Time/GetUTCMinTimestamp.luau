--local interval = 300 -- 5分钟 = 300秒

local Workspace = game:GetService("Workspace")

local function getUTCMinTimestamp(interval: number)
	-- 与 RefreshService 心跳一致，避免与 DateTime.now 边界漂移导致整点错位
	local currentTime = math.floor(Workspace:GetServerTimeNow())
	-- 计算当前时间属于哪个区间（向下取整）
	local currentIntervalStart = math.floor(currentTime / interval) * interval
	return currentIntervalStart + interval
end

return getUTCMinTimestamp