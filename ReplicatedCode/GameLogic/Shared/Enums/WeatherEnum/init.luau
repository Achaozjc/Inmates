--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeatherCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.WeatherCategory)

export type EnumType = WeatherCategory.EnumType

export type WeatherBooster = {
	woodProductionCdMultiplier: number?,
	woodCollectBonusPercent: number?,
	moneyCollectMultiplier: number?,
	processorSpeedMultiplier: number?,
}

type WeatherInfo = {
	name: string,
	icon: string,
	des: string,
	booster: WeatherBooster,
}

local WeatherEnum = {}

WeatherEnum.Emoji = {
	[WeatherCategory.Sunny] = "☀️",
	[WeatherCategory.Rain] = "🌧️",
	[WeatherCategory.Fog] = "🌫️",
	[WeatherCategory.Snow] = "❄️",
	[WeatherCategory.Thunderstorm] = "⛈️",
} :: { [WeatherCategory.EnumType]: string }

WeatherEnum.Weather = {
	[WeatherCategory.Sunny] = {
		name = WeatherCategory.Sunny,
		icon = "rbxassetid://119531317629257",
		des = "All is normal on the factory.",
		booster = {},
	} :: WeatherInfo,

	[WeatherCategory.Rain] = {
		name = WeatherCategory.Rain,
		icon = "rbxassetid://81925884515883",
		des = "Wood production cooldown -20%.",
		booster = {
			woodProductionCdMultiplier = 0.8,
		},
	} :: WeatherInfo,

	[WeatherCategory.Fog] = {
		name = WeatherCategory.Fog,
		icon = "rbxassetid://82502243391145",
		des = "Wood pickup amount +20% (rounded down).",
		booster = {
			woodCollectBonusPercent = 20,
		},
	} :: WeatherInfo,

	[WeatherCategory.Snow] = {
		name = WeatherCategory.Snow,
		icon = "rbxassetid://130574613275771",
		des = "Money collection +20%.",
		booster = {
			moneyCollectMultiplier = 1.2,
		},
	} :: WeatherInfo,

	[WeatherCategory.Thunderstorm] = {
		name = WeatherCategory.Thunderstorm,
		icon = "rbxassetid://136579182930227",
		des = "Wood processing speed +20%.",
		booster = {
			processorSpeedMultiplier = 1.2,
		},
	} :: WeatherInfo,
} :: { [WeatherCategory.EnumType]: WeatherInfo }

local weights = {
	{ category = WeatherCategory.Sunny, weight = 1200 },
	{ category = WeatherCategory.Rain, weight = 300 },
	{ category = WeatherCategory.Fog, weight = 100 },
	{ category = WeatherCategory.Snow, weight = 100 },
	{ category = WeatherCategory.Thunderstorm, weight = 45 },
} :: { { category: WeatherCategory.EnumType, weight: number } }

local function getWeather(): WeatherCategory.EnumType
	local totalWeight = 0
	for _, item in ipairs(weights) do
		totalWeight += item.weight
	end
	if totalWeight <= 0 then
		return WeatherCategory.Sunny
	end

	local chance = math.random() * totalWeight
	local cumulative = 0
	for _, item in ipairs(weights) do
		cumulative += item.weight
		if chance <= cumulative then
			return item.category
		end
	end

	return WeatherCategory.Sunny
end

function WeatherEnum.getRandomWeather(timestamp: number): WeatherCategory.EnumType
	math.randomseed(timestamp)
	return getWeather()
end

function WeatherEnum.getWeatherScheduledForRollUnix(rollUnix: number): WeatherCategory.EnumType
	math.randomseed(rollUnix)
	return getWeather()
end

function WeatherEnum.getBooster(weather: WeatherCategory.EnumType): WeatherBooster
	local info = WeatherEnum.Weather[weather]
	return if info then info.booster else {}
end

function WeatherEnum.getIcon(weather: WeatherCategory.EnumType): string
	local info = WeatherEnum.Weather[weather]
	return if info then info.icon else ""
end

return WeatherEnum
