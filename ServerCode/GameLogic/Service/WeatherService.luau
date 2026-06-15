--!strict
-- 天气每 15 分钟随 RefreshService.Timestamps[min15] 重算一次；边界为 Unix 时间轴上每 900 秒一格（UTC 的 :00/:15/:30/:45，换算到本地时刻因时区而异）
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RefreshService = require(ServerScriptService.ServerCode.GameLogic.Service.Sync.RefreshService)
local WeatherCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.WeatherCategory)
local WeatherEnum = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Enums.WeatherEnum)
local TimestampCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.TimestampCategory)
local DayNightCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.DayNightCategory)
local AttributeEnum = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Enums.AttributeEnum)

local WeatherService = {}

WeatherService.currentWeather = WeatherCategory.Clear :: WeatherCategory.EnumType

function WeatherService.applyWeather(weather: WeatherCategory.EnumType)
	WeatherService.currentWeather = weather
	ReplicatedStorage:SetAttribute(AttributeEnum.CurrentWeather, weather)
end

function WeatherService.checkWeather(timestamp: number)
	local phase = ReplicatedStorage:GetAttribute(AttributeEnum.DayNight)
	local isDay = (phase ~= DayNightCategory.Night) -- 默认视为白天

	local randomWeather = WeatherEnum.getRandomWeather(timestamp, isDay)

	if WeatherService.currentWeather == randomWeather then
		return
	end

	WeatherService.applyWeather(randomWeather)
end

function WeatherService.getWeatherBooster(): {}
	if not WeatherService.currentWeather then
		return {}
	end
	local weatherInfo = WeatherEnum.Weather[WeatherService.currentWeather :: any]
	if weatherInfo then
		return weatherInfo.booster
	end
	return {}
end

function WeatherService.listen()
	RefreshService.newMin15.Event:Connect(function(timestamp)
		WeatherService.checkWeather(timestamp)
	end)

	ReplicatedStorage:GetAttributeChangedSignal(AttributeEnum.DayNight):Connect(function()
		local currentTime = RefreshService.Timestamps[TimestampCategory.min15]
		if currentTime then
			WeatherService.checkWeather(currentTime)
		end
	end)

	local currentTime = RefreshService.Timestamps[TimestampCategory.min15]
	if currentTime then
		WeatherService.checkWeather(currentTime)
	end
end

function WeatherService.start()
	WeatherService.applyWeather(WeatherCategory.Clear)
end

return WeatherService
