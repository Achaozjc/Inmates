--!strict

--[[
	将一组 Model 排列在相机前方，始终朝向相机，支持多行网格布局。
	每帧由 RenderStepped 调用，叠加 sin 波左右摇摆动画。
--]]

local UNIT_MAX_HORIZONTAL = 5
local UNIT_FORWARD_OFFSET = 8

local function getSpacing(count: number): number
	return count > 3 and 4 or 5
end

local function arrangeModels(
	models: { Model },
	centerPoint: Vector3,
	lookPoint: Vector3,
	rowDirection: Vector3,
	rotationOffset: CFrame?
)
	local baseRotation = rotationOffset or CFrame.identity
	local n = #models
	if n == 0 then
		return
	end

	local spacing = getSpacing(n)
	local sway = math.sin(tick()) * math.rad(15)

	local camera = workspace.CurrentCamera
	local cameraPos = camera and camera.CFrame.Position or Vector3.zero

	local toCenter = (centerPoint - cameraPos)
	local toCenterMag = toCenter.Magnitude
	local camToCenter = toCenterMag > 0.001 and toCenter.Unit or camera.CFrame.LookVector
	local center = cameraPos + camToCenter * UNIT_FORWARD_OFFSET

	local lookDir = (lookPoint - center)
	local lookMag = lookDir.Magnitude
	lookDir = lookMag > 0.001 and lookDir.Unit or -camToCenter

	local worldUp = Vector3.yAxis
	local rightVec: Vector3
	local upVec: Vector3

	if math.abs(lookDir:Dot(worldUp)) > 0.99 then
		rightVec = camera.CFrame.RightVector
		upVec = lookDir:Cross(rightVec).Unit
	else
		rightVec = worldUp:Cross(lookDir).Unit
		upVec = lookDir:Cross(rightVec).Unit
	end

	local projRowDir = rowDirection - (rowDirection:Dot(lookDir)) * lookDir
	if projRowDir.Magnitude > 0.001 then
		projRowDir = projRowDir.Unit
	else
		projRowDir = rightVec
	end

	local colDir = lookDir:Cross(projRowDir).Unit

	if n == 1 then
		local cf = CFrame.lookAt(center, lookPoint, upVec)
		if models[1] and models[1].PrimaryPart then
			models[1]:PivotTo(cf * baseRotation * CFrame.Angles(0, sway, 0))
		end
		return
	end

	local rows = math.ceil(n / UNIT_MAX_HORIZONTAL)
	local middleRow = math.ceil(rows / 2)
	local totalRowH = (rows - 1) * spacing
	local startY = totalRowH / 2
	local modelsPlaced = 0

	for row = 1, rows do
		local modelsInRow = math.min(UNIT_MAX_HORIZONTAL, n - modelsPlaced)
		modelsPlaced += modelsInRow

		local rowOffset: number
		if rows % 2 == 1 then
			rowOffset = (row - middleRow) * spacing
		else
			rowOffset = startY - (row - 1) * spacing
		end

		local rowWidth = (modelsInRow - 1) * spacing
		local startX = -rowWidth / 2

		for idxInRow = 1, modelsInRow do
			local modelIdx = (row - 1) * UNIT_MAX_HORIZONTAL + idxInRow
			local model = models[modelIdx]
			if not model then
				continue
			end

			local x = startX + (idxInRow - 1) * spacing
			local position = center + projRowDir * x + colDir * rowOffset
			local cf = CFrame.lookAt(position, lookPoint, upVec)

			if model.PrimaryPart then
				model:PivotTo(cf * baseRotation * CFrame.Angles(0, sway, 0))
			end
		end
	end
end

return arrangeModels
