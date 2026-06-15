local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local PLS = game:GetService(`Players`);


local lerp = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Math.Lerp)

local RECOIL_BIND_NAME = "Recoiler"
local RECOIL_STOP_SPEED = 10
local RECOIL_ZOOM_RETURN_SPEED = 20
local RECOIL_DEFAULT_FOV = 70

local camera = Workspace.CurrentCamera
local random = Random.new()

local recoil = Vector2.zero
local zoom = 0

local function onRenderStepped(deltaTime: number)
	camera.CFrame *= CFrame.Angles(recoil.Y * deltaTime, recoil.X * deltaTime, 0)
	camera.FieldOfView = RECOIL_DEFAULT_FOV + zoom
	recoil = recoil:Lerp(Vector2.zero, math.min(deltaTime * RECOIL_STOP_SPEED, 1))
	zoom = lerp(zoom, 0, math.min(deltaTime * RECOIL_ZOOM_RETURN_SPEED, 1))
end

local CameraRecoiler = {}

function CameraRecoiler.recoil(recoilAmount: Vector2)
	zoom = 1
	recoil += recoilAmount
end

function CameraRecoiler.getRecoil(recoil)
	local xDif = recoil.max.X - recoil.min.X
	local yDif = recoil.max.Y - recoil.min.Y
	local x = recoil.min.X + random:NextNumber() * xDif
	local y = recoil.min.Y + random:NextNumber() * yDif

	local recoil = Vector2.new(math.rad(-x), math.rad(y))
	CameraRecoiler.recoil(recoil)
end



RunService:BindToRenderStep(RECOIL_BIND_NAME, Enum.RenderPriority.Camera.Value + 2, onRenderStepped)

return CameraRecoiler

