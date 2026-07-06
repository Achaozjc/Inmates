--!strict
-- 客户端自动天气视觉：监听服务端 _currentWeather，委托 WeatherSystem 处理光照与粒子

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AttributeEnum = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Enums.AttributeEnum)
local WeatherCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.WeatherCategory)
local WeatherSystem = require(ReplicatedStorage.ReplicatedCode.Framework.Managers.WeatherSystem)

local WeatherController = {
	Name = "WeatherController",
	_started = false,
}

local function readCurrentWeather(): string
	local weather = ReplicatedStorage:GetAttribute(AttributeEnum.CurrentWeather)
	if type(weather) == "string" and weather ~= "" then
		return weather
	end
	return WeatherCategory.Sunny
end

local function applyWeather()
	WeatherSystem.changeWeather(readCurrentWeather())
end

function WeatherController:init()
	if self._started then
		return
	end
	self._started = true

	WeatherSystem.start()

	-- 等待相机与 Atmosphere 就绪后再应用首帧天气
	task.defer(function()
		applyWeather()
		task.delay(1, applyWeather)
	end)

	ReplicatedStorage:GetAttributeChangedSignal(AttributeEnum.CurrentWeather):Connect(applyWeather)
end

return WeatherController
