--!strict
-- OrderedDataStore 分值规范化与榜单展示格式化（与 ShowUnitNum 等对齐）

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local formatTimestamp = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Time.FormatTimestamp)
local showUnitNum = require(ReplicatedStorage.ReplicatedCode.Framework.UI.ShowUnitNum)
local LeaderboardTypes = require(script.Parent.LeaderboardTypes)
local DecimalStringToOrderedScore = require(script.Parent.DecimalStringToOrderedScore)

local LeaderboardScore = {}

-- 将统计原始值转为可写入 OrderedDataStore 的非负整数（支持极大数值编码）
function LeaderboardScore.toOrderedStoreScore(raw: number | string, metricKind: string): number
	if typeof(raw) == "string" then
		if metricKind == LeaderboardTypes.MetricKind.Currency or metricKind == LeaderboardTypes.MetricKind.Integer then
			return DecimalStringToOrderedScore.fromUnsignedDecimalString(raw)
		end
		return 0
	end
	if raw ~= raw or raw == math.huge or raw == -math.huge then
		return 0
	end
	local n = math.max(0, math.floor(math.abs(raw)))
	
	-- 避免 n 强转 string 带来的脏位，直接走纯数学的 fromNumber 编码
	if metricKind == LeaderboardTypes.MetricKind.Currency or metricKind == LeaderboardTypes.MetricKind.Integer then
		return DecimalStringToOrderedScore.fromNumber(n)
	end
	return n
end

-- 将榜单分值格式化为展示用字符串（ODS 读回的如果是大数值将是编码后的 number；档案若用十进制字符串则直接转换）
function LeaderboardScore.formatDisplayValue(raw: number | string?, metricKind: string): string
	if raw == nil then
		if metricKind == LeaderboardTypes.MetricKind.DurationMinutes then
			return formatTimestamp.minute(0)
		end
		return showUnitNum(0)
	end
	if typeof(raw) == "string" then
		if metricKind == LeaderboardTypes.MetricKind.DurationMinutes then
			local n = tonumber(raw)
			return formatTimestamp.minute((n or 0) * 60)
		end
		if metricKind == LeaderboardTypes.MetricKind.Currency or metricKind == LeaderboardTypes.MetricKind.Integer then
			-- 对于极大字符串直接编码再解码，保证走安全的分支（防 inf），且拥有统一的科学计数法格式
			local score = DecimalStringToOrderedScore.fromUnsignedDecimalString(raw)
			local decoded = DecimalStringToOrderedScore.decodeOrderedScore(score)
			return showUnitNum(decoded)
		end
		return showUnitNum(0)
	end
	
	-- 若为 OrderedDataStore 读出的数字：
	if metricKind == LeaderboardTypes.MetricKind.DurationMinutes then
		return formatTimestamp.minute(raw * 60)
	end
	if metricKind == LeaderboardTypes.MetricKind.Currency or metricKind == LeaderboardTypes.MetricKind.Integer then
		-- decode 出来的可能是 number，也可能是极大值的 string，传给 showUnitNum 都能完美兼容
		local decoded = DecimalStringToOrderedScore.decodeOrderedScore(raw)
		return showUnitNum(decoded)
	end
	return showUnitNum(raw)
end

return LeaderboardScore
