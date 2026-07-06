--!strict
-- 天气每 5 分钟随 RefreshService.Timestamps[min5] 重算一次（移植自 dingdong WeatherManager，不含 Admin Abuse）

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RefreshService = require(ServerScriptService.ServerCode.GameLogic.Service.Sync.RefreshService)
local WeatherCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.WeatherCategory)
local WeatherEnum = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Enums.WeatherEnum)
local TimestampCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.TimestampCategory)
local AttributeEnum = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Enums.AttributeEnum)
local EnvironmentBuffHelper = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Weather.EnvironmentBuffHelper)

local WeatherService = {}

WeatherService.currentWeather = WeatherCategory.Sunny :: WeatherCategory.EnumType

function WeatherService.applyWeather(weather: WeatherCategory.EnumType)
	WeatherService.currentWeather = weather
	ReplicatedStorage:SetAttribute(AttributeEnum.CurrentWeather, weather)
end

function WeatherService.checkWeather(timestamp: number)
	local randomWeather = WeatherEnum.getRandomWeather(timestamp)
	ReplicatedStorage:SetAttribute(AttributeEnum.WeatherDuration, timestamp)

	if WeatherService.currentWeather == randomWeather then
		return
	end

	WeatherService.applyWeather(randomWeather)
end

function WeatherService.getWeatherBooster()
	return EnvironmentBuffHelper.getBuffInfo(WeatherService.currentWeather)
end

function WeatherService.listen()
	RefreshService.newMin5.Event:Connect(function(timestamp)
		WeatherService.checkWeather(timestamp)
	end)

	local currentTime = RefreshService.Timestamps[TimestampCategory.min5]
	if currentTime then
		WeatherService.checkWeather(currentTime)
	end
end

function WeatherService.start()
	WeatherService.applyWeather(WeatherCategory.Sunny)
end

return WeatherService
