local ReplicatedStorage = game:GetService("ReplicatedStorage")
local formatInteger = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Format.FormatInteger)
local UNITS = {"", "K", "M", "B", "T", "QA", "QI", "SX", "SP", "OC", "NO", "DC"}
local UNIT_THRESHOLD = 100000

local function showUnitNum(Num)
	-- 如果已经是字符串（比如因为超过 10^300 由 decodeOrderedScore 传来的极大值字符串），直接返回
	if typeof(Num) ~= "number" then
		return tostring(Num)
	end

	if math.abs(Num) < UNIT_THRESHOLD then
		return formatInteger(Num)
	end

	local absNum = math.abs(Num)
	local log10Num = math.log10(absNum)
	local exp = math.floor(log10Num / 3)
	
	if exp + 1 <= #UNITS then
		local unit = UNITS[exp + 1]
		local shortNum = Num / (10 ^ (exp * 3))
		return string.format("%.1f%s", shortNum, unit)
	else
		-- 超过了单位表的范围，使用标准的科学计数法（修复原先短数字与指数基底不匹配的 Bug）
		local trueExp = math.floor(log10Num)
		local shortNum = Num / (10 ^ trueExp)
		return string.format("%.1fe%d", shortNum, trueExp)
	end
end

return showUnitNum