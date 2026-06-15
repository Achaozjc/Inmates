
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WeatherEffects = ReplicatedStorage.Instances.CodeAssets.Effects.Weather

local WeatherParticleHandler = require(script.Parent.WeatherParticleHandler)

local MIN_SIZE = Vector3.new(0.05, 0.05, 0.05)
local RAIN_DEFAULT_COLOR = Color3.new(1, 1, 1)
local RAIN_DEFAULT_TRANSPARENCY = 0
local RAIN_DEFAULT_SPEEDRATIO = 1
local RAIN_DEFAULT_INTENSITYRATIO = 1
local RAIN_DEFAULT_LIGHTEMISSION = 0.05
local RAIN_DEFAULT_LIGHTINFLUENCE = 0.0
local RAIN_DEFAULT_DIRECTION = Vector3.new(0, -1, 0)

local RAIN_TRANSPARENCY_T1 = 0.25
local RAIN_TRANSPARENCY_T2 = 0.75

local RAIN_SCANHEIGHT = 1000

local RAIN_EMITTER_DIM_DEFAULT = 40
local RAIN_EMITTER_DIM_MAXFORWARD = 100
local RAIN_EMITTER_UP_MODIFIER = 20

local RAIN_SOUND_ASSET = "rbxassetid://1516791621"
local RAIN_SOUND_BASEVOLUME = 0.2
local RAIN_SOUND_FADEIN_TIME = 1
local RAIN_SOUND_FADEOUT_TIME = 1

local RAIN_STRAIGHT_ALPHA_LOW = 0.7
local RAIN_STRAIGHT_MAX_RATE = 500
local RAIN_STRAIGHT_MAX_SPEED = 60

local RAIN_TOPDOWN_ALPHA_LOW = 0.85
local RAIN_TOPDOWN_MAX_RATE = 600
local RAIN_TOPDOWN_MAX_SPEED = 60

local RAIN_SPLASH_ALPHA_LOW = 0.6
local RAIN_SPLASH_NUM = 10
local RAIN_SPLASH_CORRECTION_Y = 0.5
local RAIN_SPLASH_STRAIGHT_OFFSET_Y = 50
local RAIN_NOSPLASH_STRAIGHT_OFFSET_Y_MIN = 20
local RAIN_NOSPLASH_STRAIGHT_OFFSET_Y_MAX = 100

local RAIN_OCCLUDED_MAXINTENSITY = 2
local RAIN_OCCLUDECHECK_OFFSET_Y = 500
local RAIN_OCCLUDECHECK_OFFSET_XZ_MIN = -100
local RAIN_OCCLUDECHECK_OFFSET_XZ_MAX = 100
local RAIN_OCCLUDECHECK_SCAN_Y = 550

local RAIN_UPDATE_PERIOD = 6
local INDOOR_CHECK_PERIOD = 15
local RAIN_VOLUME_SCAN_RADIUS = 35
local RAIN_VOLUME_SCAN_GRID = {
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
	Name = "Rain",
	StraightParticle = WeatherEffects:WaitForChild("RainStraight"),
	TopDownParticle = WeatherEffects:WaitForChild("RainTopDown"),
	SplashParticle = WeatherEffects:WaitForChild("RainSplash"),
	SoundId = RAIN_SOUND_ASSET,

	MinSize = MIN_SIZE,
	DefaultColor = RAIN_DEFAULT_COLOR,
	DefaultTransparency = RAIN_DEFAULT_TRANSPARENCY,
	DefaultSpeedRatio = RAIN_DEFAULT_SPEEDRATIO,
	DefaultIntensityRatio = RAIN_DEFAULT_INTENSITYRATIO,
	DefaultLightEmission = RAIN_DEFAULT_LIGHTEMISSION,
	DefaultLightInfluence = RAIN_DEFAULT_LIGHTINFLUENCE,
	DefaultDirection = RAIN_DEFAULT_DIRECTION,

	TransparencyT1 = RAIN_TRANSPARENCY_T1,
	TransparencyT2 = RAIN_TRANSPARENCY_T2,

	ScanHeight = RAIN_SCANHEIGHT,
	EmitterDimDefault = RAIN_EMITTER_DIM_DEFAULT,
	EmitterDimMaxForward = RAIN_EMITTER_DIM_MAXFORWARD,
	EmitterUpModifier = RAIN_EMITTER_UP_MODIFIER,

	SoundFadeInTime = RAIN_SOUND_FADEIN_TIME,
	SoundFadeOutTime = RAIN_SOUND_FADEOUT_TIME,

	StraightAlphaLow = RAIN_STRAIGHT_ALPHA_LOW,
	StraightMaxRate = RAIN_STRAIGHT_MAX_RATE,
	StraightMaxSpeed = RAIN_STRAIGHT_MAX_SPEED,

	TopDownAlphaLow = RAIN_TOPDOWN_ALPHA_LOW,
	TopDownMaxRate = RAIN_TOPDOWN_MAX_RATE,
	TopDownMaxSpeed = RAIN_TOPDOWN_MAX_SPEED,

	SplashAlphaLow = RAIN_SPLASH_ALPHA_LOW,
	SplashNum = RAIN_SPLASH_NUM,
	SplashCorrectionY = RAIN_SPLASH_CORRECTION_Y,
	SplashStraightOffsetY = RAIN_SPLASH_STRAIGHT_OFFSET_Y,

	NoSplashStraightOffsetYMin = RAIN_NOSPLASH_STRAIGHT_OFFSET_Y_MIN,
	NoSplashStraightOffsetYMax = RAIN_NOSPLASH_STRAIGHT_OFFSET_Y_MAX,

	OccludedMaxIntensity = RAIN_OCCLUDED_MAXINTENSITY,
	OccludeCheckOffsetY = RAIN_OCCLUDECHECK_OFFSET_Y,
	OccludeCheckOffsetXZMin = RAIN_OCCLUDECHECK_OFFSET_XZ_MIN,
	OccludeCheckOffsetXZMax = RAIN_OCCLUDECHECK_OFFSET_XZ_MAX,
	OccludeCheckScanY = RAIN_OCCLUDECHECK_SCAN_Y,

	UpdatePeriod = RAIN_UPDATE_PERIOD,
	IndoorCheckPeriod = INDOOR_CHECK_PERIOD,
	VolumeScanRadius = RAIN_VOLUME_SCAN_RADIUS,
	VolumeScanGrid = RAIN_VOLUME_SCAN_GRID,
})

local Rain = {}

Rain.enabled = false

function Rain:Enable(...)
	Rain.enabled = true
	handler:Enable(...)
end

function Rain:Disable(...)
	Rain.enabled = false
	handler:Disable(...)
end

function Rain:SetColor(...)
	handler:SetColor(...)
end
function Rain:SetTransparency(...)
	handler:SetTransparency(...)
end
function Rain:SetSpeedRatio(...)
	handler:SetSpeedRatio(...)
end
function Rain:SetIntensityRatio(val: number, tweenInfo: TweenInfo?)
	handler:SetIntensityRatio(val, tweenInfo)
	-- 普通雨 0.35 → speed≈0.4，雷暴雨 1.2 → speed≈1.5
	-- 斜率 1.3 拉开差距，雷暴雨速度约为普通雨的 3.7 倍
	handler:SetSpeedRatio(0.05 + val * 1.2, tweenInfo)
end
function Rain:SetLightEmission(...)
	handler:SetLightEmission(...)
end
function Rain:SetLightInfluence(...)
	handler:SetLightInfluence(...)
end
function Rain:SetVolume(...)
	handler:SetVolume(...)
end
function Rain:SetDirection(...)
	handler:SetDirection(...)
end
function Rain:SetCeiling(...)
	handler:SetCeiling(...)
end
function Rain:SetStraightTexture(...)
	handler:SetStraightTexture(...)
end
function Rain:SetSplashTexture(...)
	handler:SetSplashTexture(...)
end
function Rain:SetSoundId(...)
	handler:SetSoundId(...)
end
function Rain:SetCollisionMode(...)
	handler:SetCollisionMode(...)
end

return Rain
