local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WeatherEffects = ReplicatedStorage.Instances.CodeAssets.Effects.Weather

local WeatherParticleHandler = require(script.Parent.WeatherParticleHandler)

local MIN_SIZE = Vector3.new(0.05, 0.05, 0.05)
local SNOW_DEFAULT_COLOR = Color3.new(1, 1, 1)
local SNOW_DEFAULT_TRANSPARENCY = 0
local SNOW_DEFAULT_SPEEDRATIO = 1
local SNOW_DEFAULT_INTENSITYRATIO = 1
local SNOW_DEFAULT_LIGHTEMISSION = 0.05
local SNOW_DEFAULT_LIGHTINFLUENCE = 0
local SNOW_DEFAULT_DIRECTION = Vector3.new(0, -1, 0)

local SNOW_TRANSPARENCY_T1 = 0.25
local SNOW_TRANSPARENCY_T2 = 0.75

local SNOW_SCANHEIGHT = 1000

local SNOW_EMITTER_DIM_DEFAULT = 40
local SNOW_EMITTER_DIM_MAXFORWARD = 100
local SNOW_EMITTER_UP_MODIFIER = 20

local SNOW_SOUND_ASSET = "rbxassetid://104234150944398"
local SNOW_SOUND_FADEIN_TIME = 1
local SNOW_SOUND_FADEOUT_TIME = 1

local SNOW_STRAIGHT_ALPHA_LOW = 0.72
local SNOW_STRAIGHT_MAX_RATE = 460
local SNOW_STRAIGHT_MAX_SPEED = 9

local SNOW_TOPDOWN_ALPHA_LOW = 0.95
local SNOW_TOPDOWN_MAX_RATE = 90
local SNOW_TOPDOWN_MAX_SPEED = 7

local SNOW_SPLASH_ALPHA_LOW = 0.6
local SNOW_SPLASH_NUM = 10
local SNOW_SPLASH_CORRECTION_Y = 0.5
local SNOW_SPLASH_STRAIGHT_OFFSET_Y = 50
local SNOW_NOSPLASH_STRAIGHT_OFFSET_Y_MIN = 20
local SNOW_NOSPLASH_STRAIGHT_OFFSET_Y_MAX = 100

local SNOW_OCCLUDED_MAXINTENSITY = 2
local SNOW_OCCLUDECHECK_OFFSET_Y = 500
local SNOW_OCCLUDECHECK_OFFSET_XZ_MIN = -100
local SNOW_OCCLUDECHECK_OFFSET_XZ_MAX = 100
local SNOW_OCCLUDECHECK_SCAN_Y = 550

local SNOW_UPDATE_PERIOD = 6
local SNOW_INDOOR_CHECK_PERIOD = 15
local SNOW_VOLUME_SCAN_RADIUS = 35
local SNOW_VOLUME_SCAN_GRID = {
	Vector3.new(0.141421363, 0, 0.141421363),
	Vector3.new(-0.141421363, 0, 0.141421363),
	Vector3.new(-0.141421363, 0, -0.141421363),
	Vector3.new(0.141421363, 0, -0.141421363),
	Vector3.new(0.400000006, 0, 0),
	Vector3.new(0.282842726, 0, 0.282842726),
	Vector3.new(2.44929371e-17, 0, 0.400000006),
	Vector3.new(-0.282842726, 0, 0.282842726),
	Vector3.new(-0.400000006, 0, 4.89858741e-17),
	Vector3.new(-0.282842726, 0, -0.282842726),
	Vector3.new(-7.34788045e-17, 0, -0.400000006),
	Vector3.new(0.282842726, 0, -0.282842726),
	Vector3.new(0.600000024, 0, 0),
	Vector3.new(0.485410213, 0, 0.352671146),
	Vector3.new(0.185410202, 0, 0.570633948),
	Vector3.new(-0.185410202, 0, 0.570633948),
	Vector3.new(-0.485410213, 0, 0.352671146),
	Vector3.new(-0.600000024, 0, 7.34788112e-17),
	Vector3.new(-0.485410213, 0, -0.352671146),
	Vector3.new(-0.185410202, 0, -0.570633948),
	Vector3.new(0.185410202, 0, -0.570633948),
	Vector3.new(0.485410213, 0, -0.352671146),
	Vector3.new(0.772740662, 0, 0.207055241),
	Vector3.new(0.565685451, 0, 0.565685451),
	Vector3.new(0.207055241, 0, 0.772740662),
	Vector3.new(-0.207055241, 0, 0.772740662),
	Vector3.new(-0.565685451, 0, 0.565685451),
	Vector3.new(-0.772740662, 0, 0.207055241),
	Vector3.new(-0.772740662, 0, -0.207055241),
	Vector3.new(-0.565685451, 0, -0.565685451),
	Vector3.new(-0.207055241, 0, -0.772740662),
	Vector3.new(0.207055241, 0, -0.772740662),
	Vector3.new(0.565685451, 0, -0.565685451),
	Vector3.new(0.772740662, 0, -0.207055241),
}

local handler = WeatherParticleHandler.new({
	Name = "Snow",
	StraightParticle = WeatherEffects:WaitForChild("SnowStraight"),
	TopDownParticle = WeatherEffects:WaitForChild("SnowTopDown"),
	SplashParticle = nil,
	SoundId = SNOW_SOUND_ASSET,

	MinSize = MIN_SIZE,
	DefaultColor = SNOW_DEFAULT_COLOR,
	DefaultTransparency = SNOW_DEFAULT_TRANSPARENCY,
	DefaultSpeedRatio = SNOW_DEFAULT_SPEEDRATIO,
	DefaultIntensityRatio = SNOW_DEFAULT_INTENSITYRATIO,
	DefaultLightEmission = SNOW_DEFAULT_LIGHTEMISSION,
	DefaultLightInfluence = SNOW_DEFAULT_LIGHTINFLUENCE,
	DefaultDirection = SNOW_DEFAULT_DIRECTION,

	TransparencyT1 = SNOW_TRANSPARENCY_T1,
	TransparencyT2 = SNOW_TRANSPARENCY_T2,

	ScanHeight = SNOW_SCANHEIGHT,
	EmitterDimDefault = SNOW_EMITTER_DIM_DEFAULT,
	EmitterDimMaxForward = SNOW_EMITTER_DIM_MAXFORWARD,
	EmitterUpModifier = SNOW_EMITTER_UP_MODIFIER,

	SoundFadeInTime = SNOW_SOUND_FADEIN_TIME,
	SoundFadeOutTime = SNOW_SOUND_FADEOUT_TIME,

	StraightAlphaLow = SNOW_STRAIGHT_ALPHA_LOW,
	StraightMaxRate = SNOW_STRAIGHT_MAX_RATE,
	StraightMaxSpeed = SNOW_STRAIGHT_MAX_SPEED,

	TopDownAlphaLow = SNOW_TOPDOWN_ALPHA_LOW,
	TopDownMaxRate = SNOW_TOPDOWN_MAX_RATE,
	TopDownMaxSpeed = SNOW_TOPDOWN_MAX_SPEED,

	SplashAlphaLow = SNOW_SPLASH_ALPHA_LOW,
	SplashNum = SNOW_SPLASH_NUM,
	SplashCorrectionY = SNOW_SPLASH_CORRECTION_Y,
	SplashStraightOffsetY = SNOW_SPLASH_STRAIGHT_OFFSET_Y,

	NoSplashStraightOffsetYMin = SNOW_NOSPLASH_STRAIGHT_OFFSET_Y_MIN,
	NoSplashStraightOffsetYMax = SNOW_NOSPLASH_STRAIGHT_OFFSET_Y_MAX,

	OccludedMaxIntensity = SNOW_OCCLUDED_MAXINTENSITY,
	OccludeCheckOffsetY = SNOW_OCCLUDECHECK_OFFSET_Y,
	OccludeCheckOffsetXZMin = SNOW_OCCLUDECHECK_OFFSET_XZ_MIN,
	OccludeCheckOffsetXZMax = SNOW_OCCLUDECHECK_OFFSET_XZ_MAX,
	OccludeCheckScanY = SNOW_OCCLUDECHECK_SCAN_Y,

	UpdatePeriod = SNOW_UPDATE_PERIOD,
	IndoorCheckPeriod = SNOW_INDOOR_CHECK_PERIOD,
	VolumeScanRadius = SNOW_VOLUME_SCAN_RADIUS,
	VolumeScanGrid = SNOW_VOLUME_SCAN_GRID,
})

local Snow = {}

Snow.enabled = false

function Snow:Enable(...)
	Snow.enabled = true
	handler:Enable(...)
end

function Snow:Disable(...)
	Snow.enabled = false
	handler:Disable(...)
end

function Snow:SetColor(...)
	handler:SetColor(...)
end
function Snow:SetTransparency(...)
	handler:SetTransparency(...)
end
function Snow:SetSpeedRatio(...)
	handler:SetSpeedRatio(...)
end
function Snow:SetIntensityRatio(...)
	handler:SetIntensityRatio(...)
end
function Snow:SetLightEmission(...)
	handler:SetLightEmission(...)
end
function Snow:SetLightInfluence(...)
	handler:SetLightInfluence(...)
end
function Snow:SetVolume(...)
	handler:SetVolume(...)
end
function Snow:SetDirection(...)
	handler:SetDirection(...)
end
function Snow:SetCeiling(...)
	handler:SetCeiling(...)
end
function Snow:SetStraightTexture(...)
	handler:SetStraightTexture(...)
end
function Snow:SetSplashTexture(...)
	handler:SetSplashTexture(...)
end
function Snow:SetSoundId(...)
	handler:SetSoundId(...)
end
function Snow:SetCollisionMode(...)
	handler:SetCollisionMode(...)
end

return Snow
