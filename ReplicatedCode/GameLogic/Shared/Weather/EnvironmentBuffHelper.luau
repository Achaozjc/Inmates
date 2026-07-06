--!strict
-- 环境加成聚合（按策划表：雨天产木 CD、雾天收集、雪天收钱、雷暴处理速度）

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AttributeEnum = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Enums.AttributeEnum)
local WeatherCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.WeatherCategory)
local WeatherEnum = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Enums.WeatherEnum)

export type BuffInfo = {
	woodProductionCdMultiplier: number,
	woodCollectBonusPercent: number,
	moneyCollectMultiplier: number,
	processorSpeedMultiplier: number,
	currentWeather: string,
}

local function getBuffInfo(currentWeatherOverride: string?): BuffInfo
	local currentWeather = (currentWeatherOverride :: string?)
		or (ReplicatedStorage:GetAttribute(AttributeEnum.CurrentWeather) :: string?)
		or WeatherCategory.Sunny

	local info: BuffInfo = {
		woodProductionCdMultiplier = 1,
		woodCollectBonusPercent = 0,
		moneyCollectMultiplier = 1,
		processorSpeedMultiplier = 1,
		currentWeather = currentWeather,
	}

	local weatherInfo = WeatherEnum.Weather[currentWeather :: WeatherCategory.EnumType]
	if not weatherInfo then
		return info
	end

	local booster = weatherInfo.booster
	if booster.woodProductionCdMultiplier then
		info.woodProductionCdMultiplier = booster.woodProductionCdMultiplier
	end
	if booster.woodCollectBonusPercent then
		info.woodCollectBonusPercent = booster.woodCollectBonusPercent
	end
	if booster.moneyCollectMultiplier then
		info.moneyCollectMultiplier = booster.moneyCollectMultiplier
	end
	if booster.processorSpeedMultiplier then
		info.processorSpeedMultiplier = booster.processorSpeedMultiplier
	end

	return info
end

local EnvironmentBuffHelper = {}

function EnvironmentBuffHelper.getBuffInfo(currentWeatherOverride: string?): BuffInfo
	return getBuffInfo(currentWeatherOverride)
end

function EnvironmentBuffHelper.getWoodProductionCdMultiplier(currentWeatherOverride: string?): number
	return getBuffInfo(currentWeatherOverride).woodProductionCdMultiplier
end

function EnvironmentBuffHelper.getWoodCollectBonusPercent(currentWeatherOverride: string?): number
	return getBuffInfo(currentWeatherOverride).woodCollectBonusPercent
end

function EnvironmentBuffHelper.getMoneyCollectMultiplier(currentWeatherOverride: string?): number
	return getBuffInfo(currentWeatherOverride).moneyCollectMultiplier
end

function EnvironmentBuffHelper.getProcessorSpeedMultiplier(currentWeatherOverride: string?): number
	return getBuffInfo(currentWeatherOverride).processorSpeedMultiplier
end

-- 雾天：收集数量 +N%，向下取整
function EnvironmentBuffHelper.applyWoodCollectBonus(amount: number, currentWeatherOverride: string?): number
	local bonusPercent = getBuffInfo(currentWeatherOverride).woodCollectBonusPercent
	if bonusPercent <= 0 then
		return amount
	end
	return math.floor(amount * (1 + bonusPercent / 100))
end

return EnvironmentBuffHelper
