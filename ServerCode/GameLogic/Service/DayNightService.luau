--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DayNightCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.DayNightCategory)
local AttributeEnum = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Enums.AttributeEnum)
local getCurrentUTC = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Time.GetCurrentUTC)

local USE_12_HOUR_FORMAT = true

-- 时间流逝速率计算：
-- 目标：30分钟现实时间 = 24小时游戏时间 (1个Day循环)
-- 公式：GameMinutes = RealSeconds * delta
-- TotalGameMinutes = 24 * 60 = 1440
-- TotalRealSeconds = 30 * 60 = 1800
-- delta = 1440 / 1800 = 0.8
local DELTA = 24 * 60 / (60 * 30)

local currentTotalMinutes = 0

local DAY_START_MIN = 6 * 60
local DAY_END_MIN = 18 * 60
local DAY_MINUTES = 24 * 60

local DayNightService = {}

local function getStudioForcedMinutes(): number?
	if not RunService:IsStudio() then
		return nil
	end

	local forcedClockTime = ReplicatedStorage:GetAttribute(AttributeEnum.StudioForceClockTime)
	if type(forcedClockTime) ~= "number" then
		return nil
	end

	local normalizedClockTime = forcedClockTime % 24
	if normalizedClockTime < 0 then
		normalizedClockTime += 24
	end

	return normalizedClockTime * 60
end

local function hour12FORMAT(hour24: number, minute: number)
	local hour12 = hour24 % 12
	if hour12 == 0 then
		hour12 = 12
	end
	local timeString = string.format("%d:%02d %s", hour12, minute, hour24 >= 12 and "PM" or "AM")
	ReplicatedStorage:SetAttribute(AttributeEnum.Clock, timeString)
end

local function hour24FORMAT(hour24: number, minute: number)
	local timeString = string.format("%02d:%02d", hour24, minute)
	ReplicatedStorage:SetAttribute(AttributeEnum.Clock, timeString)
end

local function updateClock()
	local hour24 = math.floor(currentTotalMinutes / 60) % 24
	local minute = math.floor(currentTotalMinutes % 60)

	if USE_12_HOUR_FORMAT then
		hour12FORMAT(hour24, minute)
	else
		hour24FORMAT(hour24, minute)
	end
	ReplicatedStorage:SetAttribute(AttributeEnum.ClockTime, hour24 + minute / 60)
end

local function updatePhase()
	local elapsedInDay = currentTotalMinutes % DAY_MINUTES
	if elapsedInDay >= DAY_START_MIN and elapsedInDay < DAY_END_MIN then
		ReplicatedStorage:SetAttribute(AttributeEnum.DayNight, DayNightCategory.Day)
	else
		ReplicatedStorage:SetAttribute(AttributeEnum.DayNight, DayNightCategory.Night)
	end
end

local function manageTime()
	local forcedMinutes = getStudioForcedMinutes()
	if forcedMinutes ~= nil then
		currentTotalMinutes = forcedMinutes
		updatePhase()
		updateClock()
		return
	end

	local currentUTC = getCurrentUTC()
	currentTotalMinutes = currentUTC.min * 60 * DELTA + currentUTC.sec * DELTA
	updatePhase()
	updateClock()
end

function DayNightService.start()
	task.spawn(function()
		while true do
			manageTime()
			task.wait(1)
		end
	end)
end

function DayNightService.listen() end

return DayNightService
