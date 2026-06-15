--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalCharacter = require(ReplicatedStorage.ReplicatedCode.GameLogic.Modules.LocalCharacter)
local lerp = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Math.Lerp)

local camera: Camera = Workspace.CurrentCamera :: Camera
local Janitor = require(ReplicatedStorage.ReplicatedCode.Framework.Packages.Janitor)

type Callback = (...any) -> Vector3 | CFrame

local FpsCamera = {
	affectCFrames = {} :: { [string]: Callback },
}

local janitor = Janitor.new()

local CAMERA_RENDERPRIORITY = Enum.RenderPriority.Camera.Value + 1
local CAMERA_RENDERSTEP_NAME = "FpsCamera"
local FPS_OFFSET = Vector3.new(0, 0.25, -1)
local CFRAME_ZERO = CFrame.new(Vector3.zero)
--local params = RaycastParams.new()
--params.CollisionGroup = CollisionGroup.FindWall

local config = {
	FPMaximumDistance = 2,
	FirstPersonLocalTransparency = 0,
	ThirdPersonLocalTransparency = 0,
	CAP_FPS = 60,
	CameraIncremental = 0.5, --调整幅度
	RandomScaleFactor = 200, -- 随机幅度强度
	LerpSpeed = 0.05, -- 插值的速率

	TiltFactor = 0.02, -- 倾斜幅度
	TiltLerpSpeed = 0.02,
}

local state = {
	enabled = false,
	angleX = 0,
	x = 0,
	y = 0,
	tilt = 0,
	vX = 0,
	vY = 0,
	sX = 10,
	sY = 10,
	CanImpulse = 0,
	randomX = 1,
	randomY = 1,
}

local _RANDOM = Random.new()

local function setCharacterLocalTransparency(transparency: number)
	local character = LocalCharacter.character
	if not character or not character:IsDescendantOf(workspace) then
		return
	end

	for _, part in pairs(character:GetChildren()) do
		local partParent = part.Parent
		if
			part:IsA("BasePart")
			and part.Name ~= "Head"
			and partParent
			and not partParent:IsA("Accessory")
			and not partParent:IsA("Tool")
		then
			(part :: BasePart).LocalTransparencyModifier = transparency
		end
	end
end

local function calculateCameraShake(dt: number)
	local rootPart = LocalCharacter.rootPart
	local humanoid = LocalCharacter.humanoid
	if not LocalCharacter._isAlive() or not rootPart or not humanoid then
		return
	end

	local velocity = rootPart.AssemblyLinearVelocity.Magnitude

	FpsCamera.affectResult(camera)

	dt *= 60
	state.randomX = _RANDOM:NextInteger(1, 2)
	state.randomY = _RANDOM:NextInteger(1, 2)

	state.vX = (
		dt <= 2
			and lerp(
				state.vX,
				math.cos(os.clock() * 0.5 * state.randomX) * (_RANDOM:NextInteger(5, 20) / config.RandomScaleFactor) * dt,
				config.LerpSpeed * dt
			)
		or 0
	) * config.CameraIncremental
	state.vY = (
		dt <= 2
			and lerp(
				state.vY,
				math.cos(os.clock() * 0.5 * state.randomY) * (_RANDOM:NextInteger(2, 10) / config.RandomScaleFactor) * dt,
				config.LerpSpeed * dt
			)
		or 0
	) * config.CameraIncremental

	camera.CFrame *= CFrame.Angles(0, 0, math.rad(state.angleX)) * CFrame.Angles(
		math.rad(math.clamp(state.x * dt, -0.15, 0.15)),
		math.rad(math.clamp(state.y * dt, -0.5, 0.5)),
		state.tilt
	) * CFrame.Angles(math.rad(state.vX), math.rad(state.vY), math.rad(state.vY * 10))

	state.tilt = math.clamp(
		lerp(
			state.tilt,
			-camera.CFrame:VectorToObjectSpace(rootPart.AssemblyLinearVelocity / math.max(humanoid.WalkSpeed, 0.01)).X
				* 0.05,
			config.TiltLerpSpeed * dt
		),
		-config.TiltFactor,
		config.TiltFactor
	)

	if not UserInputService.TouchEnabled and dt < 2 then
		state.angleX =
			lerp(state.angleX, math.clamp(UserInputService:GetMouseDelta().X / dt * 0.15, -2.5, 2.5), 0.25 * dt)
	end

	state.x = lerp(state.x, math.sin(os.clock() * state.sX) / 5 * math.min(1, state.sY / 10), 0.25 * dt)
	state.y = velocity > 1
			and lerp(state.y, math.cos(os.clock() * 0.5 * math.floor(state.sX)) * (state.sX / 200), 0.25 * dt)
		or lerp(state.y, 0, 0.05 * dt)
	state.sX, state.sY =
		velocity > 12 and 20 or (velocity > 0.1 and 12 or 0), velocity > 0.1 and 18 or (velocity > 0.1 and 14 or 0)
end

local function isInFirstPerson()
	local focus = camera.Focus.Position
	local origin = camera.CFrame.Position

	return (focus - origin).Magnitude <= 1
end

local function adjustCameraOffset()
	local rootPart = LocalCharacter.rootPart
	local humanoid = LocalCharacter.humanoid
	if not rootPart or not humanoid then
		return
	end
	local origin = rootPart.CFrame

	--local result = Workspace:Raycast(origin.Position, origin.LookVector * -FPS_OFFSET.Z, params)

	--if result then

	--	local distance = (result.Position - origin.Position).Magnitude
	--	if distance < math.abs(FPS_OFFSET.Z) then
	--		LocalCharacter.humanoid.CameraOffset = Vector3.new(0, 0.25, -distance)
	--	else
	--		LocalCharacter.humanoid.CameraOffset = FPS_OFFSET
	--	end
	--else
	--	LocalCharacter.humanoid.CameraOffset = FPS_OFFSET
	--end

	humanoid.CameraOffset = FPS_OFFSET
end

local function onRenderStep(dt: number)
	--calculateCameraShake(dt)

	if isInFirstPerson() then
		setCharacterLocalTransparency(config.FirstPersonLocalTransparency)
	end

	adjustCameraOffset()
end

local function enable()
	RunService:BindToRenderStep(CAMERA_RENDERSTEP_NAME, CAMERA_RENDERPRIORITY, onRenderStep)
end

local function disable()
	RunService:UnbindFromRenderStep(CAMERA_RENDERSTEP_NAME)
end

function FpsCamera.affectResult(object: BasePart | Camera): CFrame
	if typeof(object) ~= "Instance" then
		return CFRAME_ZERO
	end
	local crame = CFRAME_ZERO
	for _, callback in FpsCamera.affectCFrames do
		local Result = callback()
		if typeof(Result) == "CFrame" then
			object.CFrame *= Result
		elseif typeof(Result) == "Vector3" then
			object.CFrame += Result
		end
	end

	return crame
end

function FpsCamera.createAffect(Name: string, callback: Callback)
	Name = tostring(Name)
	if typeof(callback) ~= "function" then
		warn(`[ERROR]: Tried creating a Affect without Callback being a function! {Name}`)
		return
	end

	FpsCamera.affectCFrames[Name] = callback
end

function FpsCamera.removeAffect(Name: string)
	Name = tostring(Name)

	FpsCamera.affectCFrames[Name] = nil
end

function FpsCamera.getAffect(Name: string): () -> Vector3 | CFrame
	Name = tostring(Name)
	return FpsCamera.affectCFrames[Name]
end

function FpsCamera.setEnabled(_enabled: boolean)
	if state.enabled == _enabled then
		return
	end
	state.enabled = _enabled
	if _enabled then
		enable()
	else
		disable()
	end
end

function FpsCamera.start()
	FpsCamera.setEnabled(true)
end

return FpsCamera
