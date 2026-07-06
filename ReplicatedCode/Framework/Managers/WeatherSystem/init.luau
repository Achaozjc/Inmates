--!strict
-- 天气视觉系统（对接 Studio 已移植的 Assets / Handlers / Skys / WeatherSounds）

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")
local Workspace = game:GetService("Workspace")

local Framework = ReplicatedStorage.ReplicatedCode.Framework
local GameLogic = ReplicatedStorage.ReplicatedCode.GameLogic

local Janitor = require(Framework.Packages.Janitor)
local Thunder = require(Framework.Effects.WeatherHandle.Thunder)
local WeatherCategory = require(GameLogic.SharedConstants.Categories.WeatherCategory)
local WeatherConfig = require(script.WeatherConfig)

local CLOUDS_TWEEN = TweenInfo.new(5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local WEATHER_TWEEN = TweenInfo.new(3, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut)
local SOUND_TWEEN = TweenInfo.new(2, Enum.EasingStyle.Linear)

local Terrain = Workspace.Terrain
local Clouds = Terrain:FindFirstChildOfClass("Clouds")

local HandlerFolder = script:WaitForChild("Handlers")
local Assets = script:WaitForChild("Assets")
local Skys = script:FindFirstChild("Skys")
local WeatherSounds = script:FindFirstChild("WeatherSounds")

local EFFECT_ATTRIBUTES = { "Rain", "Snow", "Fog", "Thunderstorm" }

local WeatherHandlers = {
	[WeatherCategory.Rain] = require(HandlerFolder:WaitForChild("Rain")),
	[WeatherCategory.Snow] = require(HandlerFolder:WaitForChild("Snow")),
}

local janitor = Janitor.new()
local started = false

local fogPart = Assets:WaitForChild("Fog"):Clone()
local snowPart = Assets:WaitForChild("Snow"):Clone()

local WeatherSystem = {
	currentWeather = WeatherCategory.Sunny,
}

local function getCamera(): Camera?
	return Workspace.CurrentCamera
end

local function getParticleEmitter(part: BasePart): ParticleEmitter?
	local emitter = part:FindFirstChild("ParticleEmitter")
	if emitter and emitter:IsA("ParticleEmitter") then
		return emitter
	end
	return part:FindFirstChildWhichIsA("ParticleEmitter", true)
end

local function attachPartsToCamera()
	local camera = getCamera()
	if not camera then
		return
	end
	fogPart.Parent = camera
	snowPart.Parent = camera
end

local function setEmitterEnabled(part: BasePart, enabled: boolean)
	local emitter = getParticleEmitter(part)
	if emitter then
		emitter.Enabled = enabled
	end
end

local function tweenWeatherSound()
	if not WeatherSounds then
		return
	end

	for _, child in WeatherSounds:GetChildren() do
		if child:IsA("Sound") then
			TweenService:Create(child, SOUND_TWEEN, { Volume = 0 }):Play()
		end
	end

	local sound = WeatherSounds:FindFirstChild(WeatherSystem.currentWeather)
	if sound and sound:IsA("Sound") then
		if not sound.IsPlaying then
			sound:Play()
		end
		TweenService:Create(sound, SOUND_TWEEN, { Volume = 1 }):Play()
	end
end

local function weatherEffect()
	setEmitterEnabled(fogPart, ReplicatedStorage:GetAttribute("Fog") == true)
	setEmitterEnabled(snowPart, ReplicatedStorage:GetAttribute("Snow") == true)
end

local function handleThunder()
	if ReplicatedStorage:GetAttribute("Thunderstorm") == true then
		Thunder:Enable()
	else
		Thunder:Disable()
	end
end

local function getHandlerIntensity(weatherKey: string): number
	if weatherKey == WeatherCategory.Rain then
		if WeatherSystem.currentWeather == WeatherCategory.Thunderstorm then
			return 1
		end
		return 0.35
	end
	if weatherKey == WeatherCategory.Snow then
		return 0.65
	end
	return 0.2
end

local function handleWeather()
	for weatherKey, handler in pairs(WeatherHandlers) do
		if ReplicatedStorage:GetAttribute(weatherKey) == true then
			handler:SetIntensityRatio(getHandlerIntensity(weatherKey))
			handler:Enable(WEATHER_TWEEN)
		else
			handler:Disable(WEATHER_TWEEN)
		end
	end
	weatherEffect()
	handleThunder()
end

local function applySky(weatherName: string)
	if not Skys then
		return
	end

	local skyFolder = Skys:FindFirstChild(weatherName) or Skys:FindFirstChild("Default")
	if not skyFolder then
		return
	end

	local skySource = skyFolder:FindFirstChild("Sky")
	if not skySource or not skySource:IsA("Sky") then
		return
	end

	local existing = Lighting:FindFirstChildOfClass("Sky")
	if existing then
		existing:Destroy()
	end
	skySource:Clone().Parent = Lighting
end

local function tweenAtmosphere(props: any)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		return
	end

	local goals: { [string]: any } = {}
	if props.AtmosphereDensity then
		goals.Density = props.AtmosphereDensity
	end
	if props.AtmosphereOffset then
		goals.Offset = props.AtmosphereOffset
	end
	goals.Color = props.AtmosphereColor or Color3.fromRGB(199, 199, 199)
	goals.Decay = props.AtmosphereDecay or Color3.fromRGB(106, 112, 125)
	goals.Glare = props.AtmosphereGlare or 0
	goals.Haze = props.AtmosphereHaze or 0

	TweenService:Create(atmosphere, WEATHER_TWEEN, goals):Play()
end

local function tweenEnvironment(props: any)
	if props.Brightness then
		TweenService:Create(Lighting, WEATHER_TWEEN, { Brightness = props.Brightness }):Play()
	end

	if Clouds then
		local cloudGoals: { [string]: any } = {}
		if props.CloudsCover then
			cloudGoals.Cover = props.CloudsCover
		end
		if props.CloudsDensity then
			cloudGoals.Density = props.CloudsDensity
		end
		if next(cloudGoals) then
			TweenService:Create(Clouds, CLOUDS_TWEEN, cloudGoals):Play()
		end
	end

	if props.GrassDirection then
		TweenService:Create(Workspace, CLOUDS_TWEEN, { GlobalWind = props.GrassDirection }):Play()
	end
	if props.WaterWaveSize then
		TweenService:Create(Terrain, CLOUDS_TWEEN, { WaterWaveSize = props.WaterWaveSize }):Play()
	end
	if props.WaterWaveSpeed then
		TweenService:Create(Terrain, CLOUDS_TWEEN, { WaterWaveSpeed = props.WaterWaveSpeed }):Play()
	end
end

function WeatherSystem.changeWeather(weatherName: string?)
	local weather = weatherName or WeatherCategory.Sunny
	WeatherSystem.currentWeather = weather

	local lightingProps = WeatherConfig[weather] or WeatherConfig.Default
	if not lightingProps then
		return
	end

	tweenAtmosphere(lightingProps)
	tweenEnvironment(lightingProps)
	applySky(weather)

	for _, attrName in EFFECT_ATTRIBUTES do
		ReplicatedStorage:SetAttribute(attrName, lightingProps[attrName] == true)
		handleWeather()
	end

	tweenWeatherSound()
end

local function setup()
	attachPartsToCamera()

	janitor:Add(RunService.RenderStepped:Connect(function()
		local camera = getCamera()
		if not camera then
			return
		end
		if fogPart.Parent == camera then
			fogPart.CFrame = camera.CFrame
		end
		if snowPart.Parent == camera then
			snowPart.CFrame = camera.CFrame
		end
	end), "Disconnect")
end

function WeatherSystem.start()
	if started then
		return
	end
	if not RunService:IsClient() then
		return
	end
	started = true
	setup()
end

function WeatherSystem.stop()
	if not started then
		return
	end
	started = false
	janitor:Cleanup()

	for _, handler in pairs(WeatherHandlers) do
		handler:Disable(WEATHER_TWEEN)
	end
	Thunder:Disable()
	setEmitterEnabled(fogPart, false)
	setEmitterEnabled(snowPart, false)

	if WeatherSounds then
		for _, child in WeatherSounds:GetChildren() do
			if child:IsA("Sound") then
				child:Stop()
			end
		end
	end
end

if Skys then
	task.spawn(function()
		ContentProvider:PreloadAsync(Skys:GetChildren())
	end)
end

return WeatherSystem
