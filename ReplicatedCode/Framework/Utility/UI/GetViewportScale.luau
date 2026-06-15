--!strict

local baseResolution = Vector2.new(1920, 1080)

local function getViewportScale()
	local camera = workspace.CurrentCamera
	if not camera then
		return 1, Vector2.zero
	end
	local viewportSize = camera.ViewportSize
	local xScale = viewportSize.X / baseResolution.X
	local yScale = viewportSize.Y / baseResolution.Y
	local minScale = math.min(xScale, yScale)
	local scale = math.clamp(minScale, 0, 1)
	--local roundedScale = math.round(minScale * 10) / 10
	return scale, viewportSize
end


return getViewportScale