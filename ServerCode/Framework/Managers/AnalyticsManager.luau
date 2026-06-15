--!strict

local AnalyticsService = game:GetService("AnalyticsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local CashKey = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.CashKey)
local ItemKeyCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.ItemKeyCategory)
local OwnerIds = require(ServerScriptService.ServerCode.GameLogic.DataStore.OwnerIds)

local AnalyticsManager = {}

local function shouldSkip(player: Player): boolean
	return OwnerIds[player.UserId] ~= nil
end

local function logSafely(callback: () -> ())
	if RunService:IsStudio() then
		return
	end

	local success, err = pcall(callback)
	if not success then
		warn("[AnalyticsManager] log failed: " .. tostring(err))
	end
end

function AnalyticsManager.source(
	player: Player,
	cashKey: CashKey.EnumType | ItemKeyCategory.EnumType,
	amount: number,
	balance: number,
	transactionType: any,
	itemSku: string?,
	customFields: { [string]: number }?
)
	if shouldSkip(player) then
		return
	end

	logSafely(function()
		AnalyticsService:LogEconomyEvent(
			player,
			Enum.AnalyticsEconomyFlowType.Source,
			cashKey,
			amount,
			balance,
			transactionType,
			itemSku or "N/A",
			customFields
		)
	end)
end

function AnalyticsManager.sink(
	player: Player,
	cashKey: CashKey.EnumType | ItemKeyCategory.EnumType,
	amount: number,
	balance: number,
	transactionType: any,
	itemSku: string?,
	customFields: { [string]: number }?
)
	if shouldSkip(player) then
		return
	end

	logSafely(function()
		AnalyticsService:LogEconomyEvent(
			player,
			Enum.AnalyticsEconomyFlowType.Sink,
			cashKey,
			amount,
			balance,
			transactionType,
			itemSku or "N/A",
			customFields
		)
	end)
end

function AnalyticsManager.customEvent(
	player: Player,
	eventName: string,
	value: number?,
	customFields: { [string]: number }?
)
	if shouldSkip(player) then
		return
	end

	logSafely(function()
		AnalyticsService:LogCustomEvent(player, eventName, value, customFields)
	end)
end

function AnalyticsManager.funnelStep(
	player: Player,
	funnelName: string,
	step: number,
	stepName: string,
	sessionId: string?,
	customFields: { [string]: number }?
)
	if shouldSkip(player) then
		return
	end

	logSafely(function()
		AnalyticsService:LogFunnelStepEvent(player, funnelName, sessionId, step, stepName, customFields)
	end)
end

function AnalyticsManager.onboardingStep(player: Player, step: number, stepName: string)
	if shouldSkip(player) then
		return
	end

	logSafely(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, stepName)
	end)
end

function AnalyticsManager.progressionUnlock(player: Player, category: string, itemName: string)
	if shouldSkip(player) then
		return
	end

	local value = tonumber(string.match(itemName, "%d+$")) or 0
	local levelName = if itemName == "" then tostring(value) else itemName
	logSafely(function()
		AnalyticsService:LogProgressionEvent(
			player,
			category,
			Enum.AnalyticsProgressionType.Complete,
			value,
			levelName
		)
	end)
end

function AnalyticsManager.funnelAccumulate(
	player: Player,
	funnelName: string,
	step: number,
	stepName: string,
	customFields: { [string]: number }?
)
	if shouldSkip(player) then
		return
	end

	logSafely(function()
		AnalyticsService:LogFunnelStepEvent(player, funnelName, tostring(player.UserId), step, stepName, customFields)
	end)
end

function AnalyticsManager.progression(
	player: Player,
	category: string,
	locationValue: number,
	status: Enum.AnalyticsProgressionType
)
	if shouldSkip(player) then
		return
	end

	logSafely(function()
		AnalyticsService:LogProgressionEvent(player, category, status, locationValue, tostring(locationValue))
	end)
end

return AnalyticsManager
