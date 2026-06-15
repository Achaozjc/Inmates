--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeatherCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.WeatherCategory)

export type EnumType = WeatherCategory.EnumType
export type WeatherBooster = {
	luck: number?,
}
export type MutationWeightBonusMap = { [number]: number }

type WeatherInfo = {
	name: string,
	des: string,
	booster: WeatherBooster,
}

local WeatherEnum = {}

WeatherEnum.Weather = {
	[WeatherCategory.Clear] = {
		name = WeatherCategory.Clear,
		des = "Clear skies. No special effects.",
		booster = {},
	} :: WeatherInfo,

	[WeatherCategory.Windy] = {
		name = WeatherCategory.Windy,
		des = "Windy weather. Movement and ambient effects may feel stronger.",
		booster = { luck = 0.02 },
	} :: WeatherInfo,

	[WeatherCategory.Foggy] = {
		name = WeatherCategory.Foggy,
		des = "Misty weather. Visibility is reduced.",
		booster = { luck = 0.02 },
	} :: WeatherInfo,

	[WeatherCategory.Rain] = {
		name = WeatherCategory.Rain,
		des = "Rainy weather. Outdoor effects are active.",
		booster = { luck = 0.03 },
	} :: WeatherInfo,

	[WeatherCategory.Snow] = {
		name = WeatherCategory.Snow,
		des = "Snowy weather. Cold ambient effects are active.",
		booster = { luck = 0.03 },
	} :: WeatherInfo,

	[WeatherCategory.Thunderstorm] = {
		name = WeatherCategory.Thunderstorm,
		des = "Stormy weather. Lightning effects are active.",
		booster = { luck = 0.04 },
	} :: WeatherInfo,

	[WeatherCategory.Tornado] = {
		name = WeatherCategory.Tornado,
		des = "Tornado weather. Strong wind effects are active.",
		booster = { luck = 0.04 },
	} :: WeatherInfo,

	[WeatherCategory.Rainbow] = {
		name = WeatherCategory.Rainbow,
		des = "Rainbow weather. A rare lucky forecast.",
		booster = { luck = 0.05 },
	} :: WeatherInfo,
} :: { [WeatherCategory.EnumType]: WeatherInfo }

local weightsDay = {
	{ category = WeatherCategory.Clear, weight = 2502 },
	{ category = WeatherCategory.Foggy, weight = 2441 },
	{ category = WeatherCategory.Windy, weight = 2440 },
	{ category = WeatherCategory.Rain, weight = 2130 },
	{ category = WeatherCategory.Snow, weight = 200 },
	{ category = WeatherCategory.Thunderstorm, weight = 100 },
	{ category = WeatherCategory.Tornado, weight = 100 },
	{ category = WeatherCategory.Rainbow, weight = 87 },
} :: { { category: WeatherCategory.EnumType, weight: number } }

local weightsNight = {
	{ category = WeatherCategory.Clear, weight = 2870 },
	{ category = WeatherCategory.Foggy, weight = 2441 },
	{ category = WeatherCategory.Windy, weight = 2441 },
	{ category = WeatherCategory.Rain, weight = 2130 },
	{ category = WeatherCategory.Snow, weight = 80 },
	{ category = WeatherCategory.Thunderstorm, weight = 20 },
	{ category = WeatherCategory.Tornado, weight = 18 },
	{ category = WeatherCategory.Rainbow, weight = 0 },
} :: { { category: WeatherCategory.EnumType, weight: number } }

local function getWeather(rng: Random, isDay: boolean): WeatherCategory.EnumType
	local currentWeights = if isDay then weightsDay else weightsNight
	local totalWeight = 0
	for _, item in ipairs(currentWeights) do
		totalWeight += item.weight
	end

	local chance = rng:NextNumber() * totalWeight
	local cumulative = 0
	for _, item in ipairs(currentWeights) do
		cumulative += item.weight
		if chance <= cumulative then
			return item.category
		end
	end

	return WeatherCategory.Clear
end

function WeatherEnum.getRandomWeather(timestamp: number, isDay: boolean): WeatherCategory.EnumType
	local seed = timestamp + (if isDay then 1 else 0)
	local rng = Random.new(math.floor(seed))
	return getWeather(rng, isDay)
end

function WeatherEnum.getBooster(weather: WeatherCategory.EnumType): WeatherBooster
	local info = WeatherEnum.Weather[weather]
	return if info then info.booster else {}
end

function WeatherEnum.getMutationWeightBonus(_weather: WeatherCategory.EnumType): MutationWeightBonusMap
	return {}
end

return WeatherEnum
