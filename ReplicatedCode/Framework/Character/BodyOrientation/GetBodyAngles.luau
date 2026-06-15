local OFFSET_Y = math.rad(25) -- Avoid looking into the ground in default camera view

local function getBodyAngles(character: Model, point: Vector3): Vector2
	if character then
		local direction = character:GetPivot():PointToObjectSpace(point)

		local verticalAngle = math.asin(direction.Unit.Y)
		if verticalAngle < OFFSET_Y and verticalAngle > -OFFSET_Y then
			-- Vertical angle is within dead zone, do not change head orientation
			verticalAngle = 0
		else
			if verticalAngle > 0 then
				verticalAngle = verticalAngle - OFFSET_Y
			else
				verticalAngle = verticalAngle + OFFSET_Y
			end
		end

		local horizontalAngle = math.atan2(-direction.X, -direction.Z)
		-- If looking behind the character, it will instead rotate towards the camera
		if horizontalAngle > math.pi / 2 then
			horizontalAngle = math.pi - horizontalAngle
		elseif horizontalAngle < -math.pi / 2 then
			horizontalAngle = -math.pi - horizontalAngle
		end

		return Vector2.new(horizontalAngle, verticalAngle)
	else
		return Vector2.new(0, 0)
	end
end

return getBodyAngles
