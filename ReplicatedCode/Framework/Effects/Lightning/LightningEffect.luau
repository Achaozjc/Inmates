-- Services
local Camera = workspace.CurrentCamera
local Replicated = game:GetService('ReplicatedStorage')
local TweenService = game:GetService('TweenService')
local Debris = game:GetService('Debris')
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Terrain = workspace.Terrain
local SoundService = game:GetService("SoundService")

-- Assets
local DebrisFolder = workspace:WaitForChild("DebrisFolder")

local Modules = script.Parent.Parent.Parent

local LightningBolt = require(ReplicatedStorage.ReplicatedCode.Framework.Effects.Lightning.LightningBolt)
local LightningSparks = require(ReplicatedStorage.ReplicatedCode.Framework.Effects.Lightning.LightningBolt.LightningSparks)
local RockModule = require(script.Parent.RockModule)
local getCodeAsset = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Instance.GetCodeAsset)

local tweenInfo = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local strikeSound = SoundService.SFX.StrikeSound

local hitPrefab = getCodeAsset("Effects", "Hit") :: Part


local rand = Random.new()

local function GetXAndZPositions(Angle, Radius)
	local X = math.cos(Angle) * Radius 
	local Z = math.sin(Angle) * Radius
	return X, Z
end

local function CreateCircle(Part, Number)
	local Attachments = { }
	local FullCircle = 2 * math.pi
	local Radius = 20
	
	for i = 1, Number do
		local Attachment = Instance.new('Attachment')
		Attachment.Parent = Part
		
		local Angle = i * (FullCircle / Number)
		local X, Z = GetXAndZPositions(Angle, Radius)
		
		local Position = ( Part.CFrame * CFrame.new(X, 0, Z) ).Position
		local LookAt = Part.Position
		
		Attachment.WorldCFrame = CFrame.lookAt(Position, LookAt)
		table.insert(Attachments, Attachment)
	end
	return Attachments
end



return function(position : Vector3, hitWater: boolean?)

	-- Setup the lightning by cloning the cloud effect.
	local start = Instance.new('Attachment')
	start.Position = position + Vector3.new(0, 100, 0)
	start.Parent = Terrain
	
	-- Create a marker for the hit effect.
	local Marker = Instance.new('Attachment')
	Marker.Position = position
	Marker.Parent = Terrain
	
	-- Create the marker for the lingering thunder.
	local PartMarker = Instance.new('Part')
	PartMarker.Name = 'Marker'
	PartMarker.Position = Marker.WorldPosition
	PartMarker.Anchored = true
	PartMarker.CanCollide = false
	PartMarker.CanTouch = false
	PartMarker.Transparency = 1
	PartMarker.Size = Vector3.new(1, 1, 1)
	PartMarker.Parent = DebrisFolder
	
	-- Start the lightning effect.
	local Lightning = LightningBolt.new(start, Marker, 35)
	Lightning.MinRadius = 3.5
	Lightning.MaxRadius = 6.5
	Lightning.AnimationSpeed = 0
	Lightning.FadeLength = 0.5
	Lightning.PulseLength = 1
	Lightning.Thickness = 2
	Lightning.PulseSpeed = rand:NextInteger(3, 5)
	Lightning.Color = Color3.fromRGB(128, 157, 255)
	LightningSparks.new(Lightning)
	
	task.wait(0.25)
	
	strikeSound:Play()
	
	-- 击中特效（水面与地面共用）；地面额外溅射碎石
	local Hit = hitPrefab:Clone()
	Hit.Position = Marker.WorldPosition
	Hit.Parent = DebrisFolder
	--CamShake:Shake(CameraShaker.Presets.Lightning)
	
	for _, v in ipairs(Hit:GetDescendants()) do
		if v:IsA('ParticleEmitter') then
			v:Emit(v:GetAttribute('EmitCount'))
		end
	end
	
	local Circle = CreateCircle(PartMarker, 8)
	if not hitWater then
		RockModule.Crater(PartMarker, 8, rand:NextNumber(0.5, 1.5))
		RockModule.Crater(PartMarker, 16.5, rand:NextNumber(0.5, 1.5))
	end
	
	-- 余韵闪电
	for _ = 1, 20 do
		local Lightning = LightningBolt.new(Hit.Attachment, Circle[rand:NextInteger(1, #Circle)], 15)
		Lightning.MinRadius = 1
		Lightning.MaxRadius = 2.5
		Lightning.AnimationSpeed = 0
		Lightning.FadeLength = 0.5
		Lightning.PulseLength = 1
		Lightning.Thickness = 0.75
		Lightning.PulseSpeed = rand:NextInteger(3, 4)
		Lightning.Color = Color3.fromRGB(128, 157, 255)
		LightningSparks.new(Lightning)
		
		task.wait(0.03)
	end
	TweenService:Create(Hit.Attachment.PointLight, tweenInfo, {Brightness = 0}):Play()
	
	Debris:AddItem(Hit, 1)
	for _, attachment in ipairs(Circle) do
		attachment:Destroy()
	end
	
	-- Cleanup
	Debris:AddItem(start, 2)
	Debris:AddItem(Marker, 1)
	Debris:AddItem(PartMarker, 1)
end
