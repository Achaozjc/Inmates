local Segment = {}


local function segmentInteger(total, segmentCount)
	local segments = {}
	local average = math.floor(total / segmentCount)
	local remainder = total % segmentCount
	for i = 1, segmentCount do
		segments[i] = average
		if remainder > 0 then
			segments[i] = segments[i] + 1
			remainder = remainder - 1
		end
	end
	return segments
end

local function calculateSegmentCount(total)
	local sqrtTotal = math.sqrt(total)
	return math.max(2, math.min(5, math.floor(sqrtTotal)))
end

local function removeZeroes(tbl)
	local result = {}
	for i, value in ipairs(tbl) do
		if value ~= 0 then
			table.insert(result, value)
		end
	end
	return result
end

local function calculateAndSegment(total)
	local segmentCount = calculateSegmentCount(total)

	if segmentCount > 5 then
		segmentCount = 5
	end
	local segments = segmentInteger(total, segmentCount)
	segments = removeZeroes(segments)
	return segments
end


local function segmentTable(tbl, segmentCount)
	local total = #tbl -- 获取表中元素的总数
	local segments = {}
	local minSegmentSize = math.floor(total / segmentCount)
	local additionalElementsCount = total % segmentCount
	local startIndex = 1
	for i = 1, segmentCount do
		local segmentSize = minSegmentSize
		-- 如果累积的额外元素数量比剩余需要分配的段数多
		-- 或当前在计算最中间的段（segmentCount为奇数时）
		-- 则当前段应该多一个元素
		local isMiddleSegment = (segmentCount % 2 ~= 0 and i == math.ceil(segmentCount / 2)) or (segmentCount % 2 == 0 and (i == segmentCount / 2 or i == (segmentCount / 2) + 1))
		if additionalElementsCount > (segmentCount - i) or isMiddleSegment then
			segmentSize = segmentSize + 1
			additionalElementsCount = additionalElementsCount - 1
		end
		segments[i] = {unpack(tbl, startIndex, startIndex + segmentSize - 1)}
		startIndex = startIndex + segmentSize
	end
	return segments
end


local function calculateAndSegmentTable(tbl)
	local total = #tbl -- 获取表的大小
	local segmentCount = calculateSegmentCount(total)
	if segmentCount > 5 then
		segmentCount = 5
	end
	local segments = segmentTable(tbl, segmentCount)
	return segments
end


function Segment.SegmentInteger(int :number)
	return calculateAndSegment(int)
end

function Segment.SegmentTable(t :{ any })
	return calculateAndSegmentTable(t)
end
return Segment
