local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeatherCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.WeatherCategory)

export type LightingProperties = {
	AtmosphereColor: Color3?,
	AtmosphereDecay: Color3?,
	AtmosphereGlare: number?,
	AtmosphereHaze: number?,
	AtmosphereDensity: number,
	AtmosphereOffset: number,
	Brightness: number,
	CloudsCover: number,
	CloudsDensity: number,
	GrassDirection: Vector3?,
	WaterWaveSize: number,
	WaterWaveSpeed: number,
	isRaining: boolean?,
	isRainingIntensity: number?,
	isSnowing: boolean?,
	isSnowingIntensity: number?,
	isThundering: boolean?,
}

local WeatherConfig = {
	[WeatherCategory.Sunny] = {
		AtmosphereDensity = 0.12,
		AtmosphereOffset = 0.4,
		Brightness = 3.0,
		CloudsCover = 0.0,
		CloudsDensity = 0.0,
		WaterWaveSize = 0.12,
		WaterWaveSpeed = 2,
	},

	[WeatherCategory.Fog] = {
		AtmosphereDensity = 0.42,
		AtmosphereOffset = 0,
		AtmosphereHaze = 2.0,
		AtmosphereGlare = 0.55,
		AtmosphereColor = Color3.fromRGB(210, 215, 220),
		AtmosphereDecay = Color3.fromRGB(180, 185, 190),
		Brightness = 1.75,
		CloudsCover = 0.65,
		CloudsDensity = 0.5,
		WaterWaveSize = 0.08,
		WaterWaveSpeed = 3,
	},

	[WeatherCategory.Rain] = {
		AtmosphereDensity = 0.28,
		AtmosphereOffset = 0.05,
		Brightness = 1.5,
		CloudsCover = 0.88,
		CloudsDensity = 0.55,
		WaterWaveSize = 0.32,
		WaterWaveSpeed = 16,
		isRaining = true,
		isRainingIntensity = 0.35,
	},

	[WeatherCategory.Snow] = {
		AtmosphereDensity = 0.3,
		AtmosphereOffset = 0.05,
		AtmosphereHaze = 0.8,
		Brightness = 2.0,
		CloudsCover = 0.85,
		CloudsDensity = 0.65,
		WaterWaveSize = 0.08,
		WaterWaveSpeed = 4,
		isSnowing = true,
		isSnowingIntensity = 0.65,
	},

	[WeatherCategory.Thunderstorm] = {
		AtmosphereDensity = 0.38,
		AtmosphereOffset = 0,
		Brightness = 1.3,
		CloudsCover = 1.0,
		CloudsDensity = 0.88,
		WaterWaveSize = 0.55,
		WaterWaveSpeed = 28,
		isRaining = true,
		isThundering = true,
		isRainingIntensity = 1.2,
	},
} :: { [WeatherCategory.EnumType]: LightingProperties }

return WeatherConfig
