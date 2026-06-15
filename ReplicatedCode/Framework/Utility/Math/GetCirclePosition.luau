--!strict

local random = Random.new()


local function getCirclePosition(playerPosition: Vector3, min :number, max:number)
	-- 生成随机角度
	local angle = random:NextNumber(0, math.pi * 2) -- 随机生成0到360度的弧度
	local distance = random:NextNumber(min, max) -- 随机距离在70到100之间

	-- 使用极坐标计算目标位置
	local offsetX = distance * math.cos(angle)
	local offsetZ = distance * math.sin(angle)
	return playerPosition + Vector3.new(offsetX, 3, offsetZ)
end


return getCirclePosition
