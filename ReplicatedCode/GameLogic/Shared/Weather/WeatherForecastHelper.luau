--!strict
-- 客户端天气预报文案：与 WeatherEnum.getRandomWeather、15 分钟刷新边界对齐；游戏时刻与 DayNightService（Clock）同一套 UTC 分秒换算

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage.ReplicatedCode.Framework.Core.Network)
local AttributeEnum = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Enums.AttributeEnum)
local TimeTokenCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.TimeTokenCategory)
local TimestampCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.TimestampCategory)
local WeatherCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.WeatherCategory)
local WeatherEnum = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Enums.WeatherEnum)

local MIN15_SECONDS = TimeTokenCategory.minutes * 15

-- 与 DayNightService.updateClock 同一公式（仅用 UTC 分秒）
local DELTA = 24 * 60 / (60 * 30)
local DAY_START_MIN = 6 * 60
local DAY_END_MIN = 18 * 60
local DAY_MINUTES = 24 * 60

local function isDayGamePhaseAtUnix(unixTime: number): boolean
	local t = os.date("!*t", unixTime) :: { min: number, sec: number }
	local currentTotalMinutes = t.min * 60 * DELTA + t.sec * DELTA
	local elapsedInDay = currentTotalMinutes % DAY_MINUTES
	return elapsedInDay >= DAY_START_MIN and elapsedInDay < DAY_END_MIN
end

-- 与 ReplicatedStorage 上 Clock 属性同款 12 小时制（到达该 Unix 边界瞬间的游戏内表盘）
local function formatGameClock12hAtUnix(unixTime: number): string
	local t = os.date("!*t", unixTime) :: { min: number, sec: number }
	local currentTotalMinutes = t.min * 60 * DELTA + t.sec * DELTA
	local hour24 = math.floor(currentTotalMinutes / 60) % 24
	local minute = math.floor(currentTotalMinutes % 60)
	local hour12 = hour24 % 12
	if hour12 == 0 then
		hour12 = 12
	end
	return string.format("%d:%02d %s", hour12, minute, hour24 >= 12 and "PM" or "AM")
end

local WeatherForecastHelper = {}

function WeatherForecastHelper.getCurrentBonusesText(): string
	local current = ReplicatedStorage:GetAttribute(AttributeEnum.CurrentWeather)
	local info = WeatherEnum.Weather[current :: WeatherCategory.EnumType]
	if not info then
		info = WeatherEnum.Weather[WeatherCategory.Clear]
	end
	return string.format("Right now it's %s. %s", info.name, info.des)
end

function WeatherForecastHelper.getNextForecastTextAsync(): string
	local ok, nextTickUnix = Network.invokeServerAsync(Network.RemoteFunctions.Get_Timestamp, TimestampCategory.min15)
	if not ok or type(nextTickUnix) ~= "number" or nextTickUnix <= 0 then
		return "Sorry, I can't read the sky schedule right now."
	end

	-- RNG 种子为刷新后写入的 Timestamps[min15]；昼夜与 DayNightService 一致，取「到达本档边界」时的 UTC 分秒（≈ nextTickUnix），不可误用 rollSeed
	local rollSeed = nextTickUnix + MIN15_SECONDS
	local isDay = isDayGamePhaseAtUnix(nextTickUnix)
	local nextW = WeatherEnum.getRandomWeather(rollSeed, isDay)
	local nextInfo = WeatherEnum.Weather[nextW]

	local gameClock = formatGameClock12hAtUnix(nextTickUnix)

	return string.format(
		"Next refresh is at about %s game time. I'm seeing %s. %s",
		gameClock,
		nextInfo.name,
		nextInfo.des
	)
end

return WeatherForecastHelper
