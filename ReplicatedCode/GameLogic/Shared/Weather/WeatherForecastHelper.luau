--!strict
-- 客户端天气预报文案：与 WeatherEnum.getRandomWeather、5 分钟刷新边界对齐

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage.ReplicatedCode.Framework.Core.Network)
local AttributeEnum = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Enums.AttributeEnum)
local TimeTokenCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.TimeTokenCategory)
local TimestampCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.TimestampCategory)
local WeatherCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.WeatherCategory)
local WeatherEnum = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Enums.WeatherEnum)
local EnvironmentBuffHelper = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Weather.EnvironmentBuffHelper)

local MIN5_SECONDS = TimeTokenCategory.minutes * 5
local ROLL_INTERVAL = MIN5_SECONDS

local Workspace = game:GetService("Workspace")

local getUTCMinTimestamp = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Time.GetUTCMinTimestamp)

local DISPLAY_NAME: { [string]: string } = {
	[WeatherCategory.Fog] = "Foggy Weather",
	[WeatherCategory.Rain] = "Rainy Weather",
	[WeatherCategory.Snow] = "Snowy Weather",
	[WeatherCategory.Sunny] = "Sunny Weather",
	[WeatherCategory.Thunderstorm] = "Thunderstorm",
}

local function weatherDisplayName(key: string): string
	return DISPLAY_NAME[key] or string.format("%s Weather", key)
end

local function nextRollUnix(): number
	local nextBoundary = ReplicatedStorage:GetAttribute(AttributeEnum.WeatherDuration)
	if type(nextBoundary) == "number" then
		return nextBoundary
	end
	return getUTCMinTimestamp(MIN5_SECONDS)
end

local function formatMmSs(totalSeconds: number): string
	local s = math.max(0, math.floor(totalSeconds))
	local m = math.floor(s / 60)
	local sec = s % 60
	return string.format("%d:%02d", m, sec)
end

local DELTA = 24 * 60 / (60 * 30)
local DAY_START_MIN = 6 * 60
local DAY_END_MIN = 18 * 60
local DAY_MINUTES = 24 * 60

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

-- 与 dingdong NextWeatherBillboard 同款：下一场天气名 + 距刷新剩余时间（如 "Rainy Weather in 3:45"）
function WeatherForecastHelper.getBillboardLine(): string
	local rollAt = nextRollUnix()
	local predictAt = rollAt + ROLL_INTERVAL
	local now = Workspace:GetServerTimeNow()
	local remaining = rollAt - now
	local nextKey = WeatherEnum.getWeatherScheduledForRollUnix(predictAt)
	return string.format("%s in %s", weatherDisplayName(nextKey), formatMmSs(remaining))
end

function WeatherForecastHelper.getCurrentDisplayName(): string
	local current = ReplicatedStorage:GetAttribute(AttributeEnum.CurrentWeather)
	if type(current) ~= "string" then
		current = WeatherCategory.Sunny
	end
	return weatherDisplayName(current)
end

function WeatherForecastHelper.getCurrentBonusesText(): string
	local current = ReplicatedStorage:GetAttribute(AttributeEnum.CurrentWeather)
	local info = WeatherEnum.Weather[current :: WeatherCategory.EnumType]
	if not info then
		info = WeatherEnum.Weather[WeatherCategory.Sunny]
	end

	local buff = EnvironmentBuffHelper.getBuffInfo(current :: string?)
	local extras: { string } = {}
	if buff.woodProductionCdMultiplier < 1 then
		local percent = math.floor((1 - buff.woodProductionCdMultiplier) * 100 + 0.5)
		table.insert(extras, string.format("Wood production CD -%d%%", percent))
	end
	if buff.woodCollectBonusPercent > 0 then
		table.insert(extras, string.format("Wood pickup +%d%%", buff.woodCollectBonusPercent))
	end
	if buff.moneyCollectMultiplier > 1 then
		local percent = math.floor((buff.moneyCollectMultiplier - 1) * 100 + 0.5)
		table.insert(extras, string.format("Money collection +%d%%", percent))
	end
	if buff.processorSpeedMultiplier > 1 then
		local percent = math.floor((buff.processorSpeedMultiplier - 1) * 100 + 0.5)
		table.insert(extras, string.format("Processing speed +%d%%", percent))
	end

	local suffix = if #extras > 0 then " (" .. table.concat(extras, ", ") .. ")" else ""
	return string.format("Right now it's %s. %s%s", info.name, info.des, suffix)
end

function WeatherForecastHelper.getNextForecastTextAsync(): string
	local ok, nextTickUnix = Network.invokeServerAsync(Network.RemoteFunctions.Get_Timestamp, TimestampCategory.min5)
	if not ok or type(nextTickUnix) ~= "number" or nextTickUnix <= 0 then
		return "Sorry, I can't read the sky schedule right now."
	end

	local rollSeed = nextTickUnix + MIN5_SECONDS
	local nextW = WeatherEnum.getWeatherScheduledForRollUnix(rollSeed)
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
