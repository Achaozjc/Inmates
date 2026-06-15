local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local WorkSpace = game:GetService("Workspace")

local camera = game.Workspace.CurrentCamera


local getRayResult = {}


function getRayResult.getMouseRay()
	local mouseLocation = UserInputService:GetMouseLocation()
	return camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)
end

function getRayResult.getmouseRayResult(distance: number, raycastParams: RaycastParams)
	local unitRay = getRayResult.getMouseRay()
	return WorkSpace:Raycast(unitRay.Origin, unitRay.Direction * distance, raycastParams):: RaycastResult
end


function getRayResult.getViewportRay()
	local viewportPoint = camera.ViewportSize / 2
	return camera:ViewportPointToRay(viewportPoint.X, viewportPoint.Y) :: Ray
end

function getRayResult.getViewportRayResult(distance: number, raycastParams: RaycastParams)
	local unitRay = getRayResult.getViewportRay()
	return WorkSpace:Raycast(unitRay.Origin, unitRay.Direction * distance, raycastParams):: RaycastResult
end

return getRayResult
