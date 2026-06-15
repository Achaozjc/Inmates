-- Services
local AdService = game:GetService("AdService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage.ReplicatedCode.Framework.Core.Network)
local RemoteFunctionKey = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.RemoteFunctionKey)
local AdRewardConfig = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Configs.AdRewardConfig)

local AdManager = {}

-- 与服务端激励视频规则一致（仅供客户端展示；上限与冷却以服务端为准）
AdManager.REWARDED_VIDEO_COOLDOWN_SEC = AdRewardConfig.COOLDOWN_SEC
AdManager.REWARDED_VIDEO_DAILY_MAX = AdRewardConfig.DAILY_MAX

local AD_AVAILABILITY_CACHE_SEC = 30
local cachedAvailability: boolean? = nil
local cachedAvailabilityAt = 0

local INELIGIBLE_RESULTS = {
	Enum.AdAvailabilityResult.PlayerIneligible,
	Enum.AdAvailabilityResult.DeviceIneligible,
	Enum.AdAvailabilityResult.PublisherIneligible,
	Enum.AdAvailabilityResult.ExperienceIneligible,
}

local function isIneligible(result: Enum.AdAvailabilityResult)
	for _, inEligibleResult in ipairs(INELIGIBLE_RESULTS) do
		if result == inEligibleResult then
			return true
		end
	end

	return false
end

function AdManager.invalidateRewardedVideoAvailability()
	cachedAvailability = nil
	cachedAvailabilityAt = 0
end

function AdManager.hasFreshRewardedVideoAvailability(): boolean
	return cachedAvailability ~= nil and os.clock() - cachedAvailabilityAt < AD_AVAILABILITY_CACHE_SEC
end

function AdManager.isRewardedVideoAvailable(forceRefresh: boolean?): boolean
	local now = os.clock()
	if not forceRefresh and cachedAvailability ~= nil and now - cachedAvailabilityAt < AD_AVAILABILITY_CACHE_SEC then
		return cachedAvailability
	end

	local isSuccess, result = pcall(function()
		return AdService:GetAdAvailabilityNowAsync(Enum.AdFormat.RewardedVideo)
	end)

	if not isSuccess or not result then
		cachedAvailability = false
		cachedAvailabilityAt = now
		return false
	end

	if result.AdAvailabilityResult == Enum.AdAvailabilityResult.IsAvailable then
		cachedAvailability = true
		cachedAvailabilityAt = now
		return true
	end

	if isIneligible(result.AdAvailabilityResult) then
		cachedAvailability = false
		cachedAvailabilityAt = now
		return false
	end

	cachedAvailability = false
	cachedAvailabilityAt = now
	return false
end

-- 兼容旧接口名（商店等 UI 调用）
function AdManager.checkForAds(): boolean?
	return AdManager.isRewardedVideoAvailable(true) or nil
end

-- 由服务端拉起 ShowRewardedVideoAdAsync；成功时发奖在 ProcessReceipt
function AdManager.requestRewardedVideoFromServer(): (boolean, string?)
	local ok, success, errMsg = Network.invokeServerAsync(RemoteFunctionKey.RewardedAdEvent)
	if not ok then
		return false, tostring(success)
	end
	if success then
		return true, nil
	end
	local errStr = tostring(errMsg)
	if type(errMsg) == "string" then
		errStr = errMsg
	end
	return false, errStr
end

return AdManager
