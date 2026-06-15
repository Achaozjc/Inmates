local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CollisionGroup = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Misc.CollisionGroup)
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local DownVector = Vector3.yAxis * -100
local VerticalRayOffsetVector = Vector3.yAxis

local rayCastParams = RaycastParams.new()
rayCastParams.CollisionGroup = CollisionGroup.EffectRay


local tweenInfo = TweenInfo.new(0.5) -- 0.5秒的时间

local DEFAULT_DURATION = 0.3
local DEFAULT_DISTANCE = 10
local DEFAULT_HEIGHT = 5

local INITIAL_SCALE = 0.1
local FINAL_SCALE = 1
local BOUNCE_HEIGHT = 1 -- Height to bounce
local BOUNCE_DURATION = 0.3 -- Duration of the bounce
local check_radius = 2 -- 设置检查半径

local CFRAME_ZERO = CFrame.new()
local vectorCreate = Vector3.new

local rand = Random.new()

type Callback = (...any) -> ...any

local Throw = {}


local function ArcPosition(startPosition, endPosition, t, height)
	local midpoint = (startPosition + endPosition) / 2
	midpoint = midpoint + vectorCreate(0, height, 0)

	local Lerp1 = startPosition:Lerp(midpoint, t)
	local Lerp2 = midpoint:Lerp(endPosition, t)
	return Lerp1:Lerp(Lerp2, t)
end


function Throw.getPositionAroundCharacter(rootCFrame :CFrame, distance: number?, random: boolean?): Vector3
	local direction : Vector3
	if random then
		direction = vectorCreate(rand:NextNumber() - 0.5, 0, rand:NextNumber() - 0.5).Unit
	else
		direction = rootCFrame.LookVector.Unit
	end
	local originPosition = rootCFrame.Position + direction * (distance or DEFAULT_DISTANCE)
	local RaycastResult = Workspace:Raycast(originPosition, DownVector, rayCastParams)

	if RaycastResult then
		return vectorCreate(originPosition.X, RaycastResult.Position.Y , originPosition.Z)
	else
		return vectorCreate(originPosition.X, 2.5, originPosition.Z)
	end
end


local function backwards(model: Model)
	local root = model.PrimaryPart ::BasePart
	local dir = root.CFrame.LookVector
	local newCFrame = root.CFrame + vectorCreate(dir.X, 0, dir.Z) * -rand:NextInteger(3, 5)
	local backTween = TweenService:Create(root, tweenInfo, {CFrame = newCFrame}) :: Tween
	backTween:Play()
	Debris:AddItem(backTween, 1)
end


local function makePositionAndFace(object: Model, endPosition: Vector3, targetPosition: Vector3)
	local lookAtCFrame = CFrame.lookAt(endPosition, vectorCreate(targetPosition.X, endPosition.Y, targetPosition.Z))
	object:PivotTo(lookAtCFrame)
end



local function bounceEffect(object: Model, endPosition: Vector3, targetPosition: Vector3, callback: Callback?)
	-- Bounce effect
	local bounceStartTime = os.clock()
	local bounceConnection

	bounceConnection = RunService.RenderStepped:Connect(function(deltaTime)
		local bounceElapsed = os.clock() - bounceStartTime
		local bounceT = math.min(bounceElapsed / BOUNCE_DURATION, 1)

		-- Calculate bounce position
		local bouncePosition = endPosition.Y + (math.sin(bounceT * math.pi) * BOUNCE_HEIGHT)

		-- 更新朝向
		local lookAtCFrame = CFrame.lookAt(vectorCreate(endPosition.X, bouncePosition, endPosition.Z), vectorCreate(targetPosition.X, bouncePosition, targetPosition.Z))
		object:PivotTo(lookAtCFrame)

		if bounceT >= 1 then
			bounceConnection:Disconnect()
			makePositionAndFace(object, endPosition, targetPosition) -- Final position correction if needed
			object:SetAttribute("end", true)
			if callback then
				callback()
			end
			if object:GetAttribute("back") then
				backwards(object)
			end
		end
	end)
end



function Throw.Animate(object: Model, rootCFrame: CFrame, endPosition: Vector3, totalTime, height, callback: Callback?)
	local startTime = os.clock()
	local startPosition = rootCFrame.Position
	local startCFrame = object:GetPivot()
	local targetPosition = rootCFrame.Position
	local totalTime = totalTime or DEFAULT_DURATION
	local eTime = 0

	-- Set initial scale
	object:ScaleTo(INITIAL_SCALE)

	local connection
	connection = RunService.RenderStepped:Connect(function(deltaTime)
		eTime = os.clock() - startTime
		local t = math.min(eTime / totalTime, 1)

		-- Scale the object
		local currentScale = INITIAL_SCALE + (FINAL_SCALE - INITIAL_SCALE) * t
		object:ScaleTo(currentScale)
		
		if t >= 1 then
			-- On reach the final position, we connect the bounce effect
			connection:Disconnect()	
		
			--makePositionAndFace(object, endPosition, targetPosition)		
			--bounceEffect(object, endPosition, targetPosition, callback)
			if callback then
				callback()
			end
			return
		end

		-- Move alongside the arc
		local newPosition = ArcPosition(startPosition, endPosition, t, height)
		makePositionAndFace(object, newPosition, targetPosition)		
	end)
end



return Throw
