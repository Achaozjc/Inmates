--!strict

local random = Random.new()


local function getPartRandomCFrame(basepart: BasePart, needCFrame: boolean?, randomY: boolean? ) :CFrame | Vector3
	local size = basepart.Size
	local position = basepart.Position

	-- 控制偏移量，使其不靠近边缘
	local marginFactor = 0.1 -- 控制偏移量的范围（0 到 0.5之间）
	local offsetRange = (0.5 - marginFactor / 2)

	local xOffset = (random:NextNumber(-offsetRange, offsetRange))
	local zOffset = (random:NextNumber(-offsetRange, offsetRange))
	local yOffset = 0
	if randomY then
		yOffset = random:NextNumber(-offsetRange, offsetRange)
	end

	local offset = Vector3.new(xOffset, yOffset, zOffset) * size
	
	if needCFrame then
		return CFrame.new(position + offset)
	else
		
		return position + offset
	end
end


return getPartRandomCFrame
