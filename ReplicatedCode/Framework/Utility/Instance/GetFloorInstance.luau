--!strict
local WorkSpace = game:GetService("Workspace")

local UpVector = Vector3.yAxis * 3
local DownVector = Vector3.yAxis * -100

-- collisionGroup: 传入碰撞组名称，默认 "Default"；由调用方（GameLogic）传入游戏专属碰撞组
local function getFloorInstance(start: CFrame | Vector3, collisionGroup: string?)
	local startPosition: Vector3
	if typeof(start) == "Vector3" then
		startPosition = start :: Vector3
	else
		startPosition = (start :: CFrame).Position
	end

	local params = RaycastParams.new()
	params.CollisionGroup = collisionGroup or "Default"
	return WorkSpace:Raycast(startPosition + UpVector, DownVector, params)
end

return getFloorInstance
