--!strict

-- 全服木料倍率刷新参数（端共享）
local WoodMultiplierConfig = {
	REFRESH_INTERVAL = 30, -- 刷新间隔（秒）
	MIN = 1,
	MAX = 1.5,
	PREFAB_NAME = "WoodMultiplierGui", -- ReplicatedStorage/Instances/Prefabs/Gui 下的 SurfaceGui 预制体
	ATTR_MULTIPLIER = "_woodMultiplier", -- 写在 Workspace 上，供晚加入客户端读取
	ATTR_NEXT_REFRESH_AT = "_woodMultiplierNextRefreshAt",
	HANDLE_MIN_SCALE = 0, -- 倍率最高时 Handle 最小宽度（X Scale）
	DISPLAY_DECIMALS = 1, -- 倍率精度：显示与入库计算共用
}

local function formatValue(multiplier: number): string
	local decimals = WoodMultiplierConfig.DISPLAY_DECIMALS
	local quantized = WoodMultiplierConfig.quantize(multiplier)
	if decimals <= 0 then
		return string.format("%d", quantized)
	end
	-- Luau 不支持 %.*f，按 DISPLAY_DECIMALS 拼接固定精度模板
	return string.format("%." .. tostring(decimals) .. "f", quantized)
end

-- 将倍率量化到 DISPLAY_DECIMALS 位小数并限制在 [MIN, MAX]
function WoodMultiplierConfig.quantize(multiplier: number): number
	local factor = 10 ^ WoodMultiplierConfig.DISPLAY_DECIMALS
	local rounded = math.round(multiplier * factor) / factor
	return math.clamp(rounded, WoodMultiplierConfig.MIN, WoodMultiplierConfig.MAX)
end

function WoodMultiplierConfig.normalize(multiplier: number): number
	local span = WoodMultiplierConfig.MAX - WoodMultiplierConfig.MIN
	if span <= 0 then
		return 0
	end
	return math.clamp((multiplier - WoodMultiplierConfig.MIN) / span, 0, 1)
end

function WoodMultiplierConfig.formatDisplay(multiplier: number): string
	return formatValue(multiplier) .. "x"
end

-- 存入通知中的倍率片段，如 "×1.0"
function WoodMultiplierConfig.formatNotify(multiplier: number): string
	return "×" .. formatValue(multiplier)
end

-- 入库换算：背负 Wood 价值 × 当前倍率后向上取整 = 实际进入处理机的量（如 3 × 1.2 → 4）
function WoodMultiplierConfig.applyToDeposit(woodValue: number, multiplier: number): number
	if woodValue <= 0 or multiplier <= 0 then
		return 0
	end
	local quantizedMultiplier = WoodMultiplierConfig.quantize(multiplier)
	return math.ceil(woodValue * quantizedMultiplier)
end

-- Bar.Handle 右对齐反向进度：Position 固定右侧，仅改 Size.X.Scale（1.0x→1.0，1.5x→MIN）
function WoodMultiplierConfig.getHandleSizeX(multiplier: number): number
	local t = WoodMultiplierConfig.normalize(multiplier)
	local minScale = WoodMultiplierConfig.HANDLE_MIN_SCALE
	return 1 - t * (1 - minScale)
end

return WoodMultiplierConfig
