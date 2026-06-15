local guidCharsText = "1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!@#$%^&*()_+./"
local guidChars = {}
for i = 1, #guidCharsText do
	guidChars[i] = guidCharsText:sub(i, i)
end

local rand = Random.new()

-- 简单的自增计数器，跨调用时保持递增（需要在全局范围内持久化）
local _guidCounter = 0

local function getGuid()
	-- 1) 5 位随机字符
	local part1 = {}
	for _ = 1, 6 do
		local idx = rand:NextInteger(1, #guidChars)
		part1[#part1 + 1] = guidChars[idx]
	end
	local randPart = table.concat(part1)

	-- 2) 时间戳片段（更安全的做法：使用 os.clock() 的高精度部分）
	local ts = tostring(os.clock())
	local tsPart = ts:sub(-4)  -- 使用最后 6 位，减少重复概率

	-- 3) 自增计数器，确保同一时间戳下也不重复
	_guidCounter = (_guidCounter + 1) % 1000  -- 3 位自增，避免过长
	local counterPart = string.format("%03d", _guidCounter)

	local guid = randPart .. tsPart .. counterPart
	return guid
end

return getGuid
