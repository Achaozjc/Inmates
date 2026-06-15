--生成圆上等分点的函数
local function generateCirclePoints(center, radius, numPoints)
	local points = {}
	local angleIncrement = (2 * math.pi) / numPoints

	for i = 0, numPoints - 1 do
		local angle = i * angleIncrement
		local x = center.X + radius * math.cos(angle)
		local y = center.Y 
		local z = center.Z + radius * math.sin(angle)
		table.insert(points, Vector3.new(x, y, z))
	end

	return points
end

return generateCirclePoints

---- 示例
--local center = Vector3.new(0, 0, 0)
--local radius = 10
--local numPoints = 12
--local circlePoints = generateCirclePoints(center, radius, numPoints)

---- 输出结果
--for i, point in ipairs(circlePoints) do
--	print(string.format("Point %d: (%.2f, %.2f, %.2f)", i, point.X, point.Y, point.Z))
--end