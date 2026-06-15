--!strict

local SATURATION = 0.5 -- 比较低的饱和度
local VALUE = 0.95 -- 亮度保持不变
local OFFSET = 0 -- 默认偏移


local function getRandomColor(i:number, sat :number?, val:number?, offset:number?)
	local index = i - 1
	local phi = 1.6180339887498948
	return Color3.fromHSV((phi * i + (offset or OFFSET)) % 1, (sat or SATURATION), (val or VALUE))
end


return getRandomColor
