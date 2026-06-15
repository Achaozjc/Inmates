--!strict
-- 编码方案：将字符串长度（代表指数）与前14位数字（尾数）组合，牺牲 14 位后的精度来换取 10^92230 的动态范围排序。
-- OrderedDataStore 极限为 9.22e18（19位有符号整数）。因此，小于 10^14 (15位) 的数字原样无损存储；
-- 15位及以上的数字编码为：L * 10^14 + mantissa（前14位）。

local ENCODE_THRESHOLD_L = 15
local ENCODE_OFFSET = 10^14

local module = {}

local function trimUnsignedDigits(s: string): string?
	local digits = s:match("^%s*(%d+)%s*$")
	if not digits or digits == "" then
		return nil
	end
	digits = digits:gsub("^0+", "")
	if digits == "" then
		return "0"
	end
	return digits
end

-- 1. 将十进制字符串编码（精确到前 14 位，抛弃末尾降低碰撞面但不影响量级排序）
function module.fromUnsignedDecimalString(s: string): number
	local d = trimUnsignedDigits(s)
	if not d then
		return 0
	end
	
	local L = #d
	if L < ENCODE_THRESHOLD_L then
		return tonumber(d) or 0
	end
	
	-- 限制 L 的最大值（避免在极端情况下超过双精度整数表示范围 9.22e18）
	-- L = 92230 时，支持 10^92230，绝对不溢出 int64
	if L > 92230 then 
		L = 92230 
	end
	
	local mantissa = tonumber(d:sub(1, 14)) or 0
	return L * ENCODE_OFFSET + mantissa
end

-- 2. 将普通 double 编码，避免走 string.format("%.0f") 带来的脏位与性能损耗
function module.fromNumber(n: number): number
	if n < 0 then n = 0 end
	if n ~= n or n == math.huge then return 92230 * ENCODE_OFFSET end
	
	if n < 10^14 then
		return math.floor(n)
	end
	
	local L = math.floor(math.log10(n)) + 1
	if L > 92230 then L = 92230 end
	
	local mantissa = math.floor(n / (10 ^ (L - 14)))
	return L * ENCODE_OFFSET + mantissa
end

-- 3. 解码展示：如果超过 10^300，直接返回格式化的科学计数法字符串，彻底杜绝 math.huge (inf) 炸裂
function module.decodeOrderedScore(score: number): number | string
	if score < ENCODE_THRESHOLD_L * ENCODE_OFFSET then
		return score
	end
	
	local L = math.floor(score / ENCODE_OFFSET)
	local mantissa = score % ENCODE_OFFSET
	
	-- 如果数值接近或超过 Lua double 的 10^308 极限，直接以字符串返回
	if L > 300 then
		local mantissaStr = string.format("%014d", mantissa)
		local firstDigit = mantissaStr:sub(1, 1)
		local restDigits = mantissaStr:sub(2, 2) -- 保留1位小数用于 UI 展示
		return string.format("%s.%se%d", firstDigit, restDigits, L - 1)
	end
	
	-- 在安全范围内，还原为 double 交给 UI 系统处理
	return mantissa * (10 ^ (L - 14))
end

return module
