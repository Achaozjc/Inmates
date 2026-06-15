--!strict

-- 全服木料倍率刷新参数（端共享）
local WoodMultiplierConfig = {
	REFRESH_INTERVAL = 30, -- 刷新间隔（秒）
	MIN = 0.5,
	MAX = 1.5,
	PREFAB_NAME = "WoodMultiplierGui", -- ReplicatedStorage/Instances/Prefabs/Gui 下的 SurfaceGui 预制体
	ATTR_MULTIPLIER = "_woodMultiplier", -- 写在 Workspace 上，供晚加入客户端读取
	ATTR_NEXT_REFRESH_AT = "_woodMultiplierNextRefreshAt",
	HANDLE_MIN_SCALE = 0, -- 倍率最高时 Handle 最小宽度（X Scale）
}

function WoodMultiplierConfig.normalize(multiplier: number): number
	local span = WoodMultiplierConfig.MAX - WoodMultiplierConfig.MIN
	if span <= 0 then
		return 0
	end
	return math.clamp((multiplier - WoodMultiplierConfig.MIN) / span, 0, 1)
end

function WoodMultiplierConfig.formatDisplay(multiplier: number): string
	return string.format("%.1fx", multiplier)
end

-- 入库换算：背负 Wood 价值 × 当前倍率后向上取整 = 实际进入处理机的量（如 3 × 0.5 → 2）
function WoodMultiplierConfig.applyToDeposit(woodValue: number, multiplier: number): number
	if woodValue <= 0 or multiplier <= 0 then
		return 0
	end
	return math.ceil(woodValue * multiplier)
end

-- Bar.Handle 右对齐反向进度：Position 固定右侧，仅改 Size.X.Scale（0.5x→1.0，1.5x→MIN）
function WoodMultiplierConfig.getHandleSizeX(multiplier: number): number
	local t = WoodMultiplierConfig.normalize(multiplier)
	local minScale = WoodMultiplierConfig.HANDLE_MIN_SCALE
	return 1 - t * (1 - minScale)
end

return WoodMultiplierConfig
