-- Services

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TweenService = game:GetService('TweenService')
local Debris = game:GetService('Debris')
local DebrisFolder = workspace:WaitForChild("DebrisFolder")

local CollisionGroup = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Misc.CollisionGroup)
local RaycastParam = RaycastParams.new()
RaycastParam.CollisionGroup = CollisionGroup.EffectRay

local rand = Random.new()

local function VelocityNew(Strength, Duration, Parent)
	local Velocity = Instance.new('BodyVelocity')
	Velocity.Name = 'Velocity'
	Velocity.MaxForce = Vector3.new(1, 1, 1) * math.huge
	Velocity.Velocity = Strength
	Velocity.Parent = Parent
	Debris:AddItem(Velocity, Duration)
end

return {
	['Debris'] = function(Object, Scale, Strength, Amount)

		for _ = 1, Amount or 15 do
			local Rock = Instance.new('Part')
			Rock.Name = 'Rock'
			Rock.Position = Object.Position + Vector3.new(rand:NextNumber(-7.5, 7.5), 3, rand:NextNumber(-7.5, 7.5))
			Rock.Size = Vector3.new(Scale, Scale, Scale)
			Rock.CanTouch = false
			Rock.CanCollide = false

			local Raycast = workspace:Raycast(Rock.Position, Rock.CFrame.UpVector * -5, RaycastParam)
			if Raycast then
				Rock.Material = Raycast.Material
				Rock.Color = Raycast.Instance.Color
				Rock.Orientation = Vector3.new(rand:NextInteger(-180, 180), rand:NextInteger(-180, 180), rand:NextInteger(-180, 180))
				Rock.Parent = DebrisFolder
				
				VelocityNew(Rock.CFrame.UpVector * Strength, 0.35, Rock)
				TweenService:Create(Rock, TweenInfo.new(0.4, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), {Orientation = Rock.Orientation + Vector3.new(360, 360, 360)}):Play()

				Debris:AddItem(Rock, 5)
			end
		end
	end,
	
	['Crater'] = function(Object, Radius, Size, Amount, AngleIndex)
		local Angle = 0

	

		for _ = 1, Amount or 18 do
			local Scale = Size
			
			local Rock = Instance.new('Part')
			Rock.Name = 'RockCrater'
			Rock.Anchored = true
			Rock.CanCollide = false
			Rock.CanTouch = false
			Rock.CFrame = Object.CFrame * CFrame.fromEulerAnglesXYZ(0, math.rad(Angle), 0) * CFrame.new(0, 1, -Radius)
			Rock.Size = Vector3.new(Scale, Scale, Scale)

			local Raycast = workspace:Raycast(Rock.Position, Rock.CFrame.UpVector * -5, RaycastParam)
			
			if Raycast then
				Rock.CFrame = Rock.CFrame * CFrame.new(0, -Scale + -1, 0)
				Rock.Material = Raycast.Material
				Rock.Color = Raycast.Instance.Color
				Rock.Parent = DebrisFolder
				TweenService:Create(Rock, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = Rock.Position + Vector3.new(0, Scale, 0), Orientation = Vector3.new(rand:NextInteger(-180, 180), rand:NextInteger(-180, 180), rand:NextInteger(-180, 180))}):Play()

				coroutine.wrap(function()
					task.wait(3)
					TweenService:Create(Rock, TweenInfo.new(rand:NextInteger(1, 2), Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = Rock.Position + Vector3.new(0, -Scale, 0), Orientation = Vector3.new(Rock.Orientation.X, Rock.Orientation.Y, -70)}):Play()
					Debris:AddItem(Rock, 4)
				end)()
			end

			Angle += AngleIndex or 20
		end
	end,
}
