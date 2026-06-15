local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraShake = require(ReplicatedStorage.ReplicatedCode.Framework.Effects.CameraShake)
local camera = workspace.CurrentCamera

local renderPriority = Enum.RenderPriority.Camera.Value

local Shake = {}


local elevatorShake = CameraShake.new()
elevatorShake.Amplitude = 0.04
elevatorShake.Frequency = 0.1
elevatorShake.FadeInTime = 0
elevatorShake.FadeOutTime = 1.5

local explosionShake = CameraShake.new()
explosionShake.Amplitude = 10
explosionShake.Frequency = 0.5
explosionShake.FadeInTime = 0
explosionShake.FadeOutTime = 2

local elevatorSlide = CameraShake.new()
elevatorSlide.Amplitude = 0.02
elevatorSlide.Frequency = 0.05
elevatorSlide.FadeInTime = 0
elevatorSlide.FadeOutTime = 1
elevatorSlide.Sustain = true

function Shake.elevator()
	elevatorShake:BindToRenderStep("ElevatorShake", renderPriority, function(pos: Vector3, rot: Vector3 ,done: boolean)
		camera.CFrame *= CFrame.new(pos) * CFrame.Angles(rot.X, rot.Y, rot.Z)
		if done then
			elevatorShake:Stop()
		end
	end)
	elevatorShake:Start()
end

function Shake.slideElevator()
	if elevatorSlide:IsShaking() then
		return
	end
	elevatorSlide:BindToRenderStep("SlideElevator", renderPriority, function(pos: Vector3, rot: Vector3 ,done: boolean)
		camera.CFrame *= CFrame.new(pos) * CFrame.Angles(rot.X, rot.Y, rot.Z)
	end)
	elevatorSlide:Start()
end

function Shake.stopSlideElevator()
	if elevatorSlide:IsShaking() then
		elevatorSlide:StopSustain()
	end	
end


function Shake.explosion(positionOfExplosion: Vector3)
	
	explosionShake:BindToRenderStep(CameraShake.NextRenderName(), renderPriority, function(pos: Vector3, rot: Vector3 ,done: boolean)
		local distance = (camera.CFrame.Position - positionOfExplosion).Magnitude
		pos = CameraShake.InverseSquare(pos, distance)
		rot = CameraShake.InverseSquare(rot, distance)
		camera.CFrame *= CFrame.new(pos) * CFrame.Angles(rot.X, rot.Y, rot.Z)
		if done then
			explosionShake:Stop()
		end
	end)
	explosionShake:Start()
end


return Shake

