local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataStoreWrapper = require(ServerScriptService.ServerCode.Framework.DataStore.Modules.DataStoreWrapper)
local GameSetting = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Settings.GameSetting)
local HttpProxyService = require(ServerScriptService.ServerCode.Framework.DataStore.Modules.HttpProxyService)
local CodeConfig = require(ServerScriptService.ServerCode.GameLogic.DataStore.CodeConfig)
local setInterval = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Time.SetInterval)
local NetSignals = require(ReplicatedStorage.ReplicatedCode.Framework.Core.Network.NetSignals)
local TriggerSignalCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.TriggerSignalCategory)

local DATA_STORE_NAME = GameSetting.CODE_DATA_NAME
local AUTO_SAVE_INTERVAL = 600

local CodeDataServer = {}

CodeDataServer._baseDataWrapper = DataStoreWrapper.new(
	DATA_STORE_NAME,
	GameSetting.DATA_STORE_REQUEST_ATTEMPTS,
	GameSetting.DATA_STORE_REQUEST_COOLDOWN_CONSTANT,
	GameSetting.DATA_STORE_REQUEST_COOLDOWN_EXPONENT
)
CodeDataServer._likes = 0
CodeDataServer._started = false
CodeDataServer._startupLikesLogged = false
CodeDataServer._releasedCodes = {} :: { [string]: number }

local function normalizeCode(code: string): string
	return string.lower(code)
end

local function markReleased(releasedCodes: { [string]: number }, code: string, unlockTick: number)
	releasedCodes[code] = unlockTick
	releasedCodes[normalizeCode(code)] = unlockTick
end

local function getUnlockedAt(code: string): number?
	return CodeDataServer._releasedCodes[code] or CodeDataServer._releasedCodes[normalizeCode(code)]
end

local function isWithinExpiration(unlockedAt: number): boolean
	local now = workspace:GetServerTimeNow()
	return now - unlockedAt <= CodeConfig.EXPIRATION
end

function CodeDataServer.start(DataStoreName: string?)
	assert(not CodeDataServer._started, "CodeDataServer has already been started")

	CodeDataServer._started = true
	CodeDataServer._likes = 0
	CodeDataServer._releasedCodes = {}
	CodeDataServer._startAutoSaveLoop()
end

function CodeDataServer.checkCodeRelease()
	local votes = HttpProxyService.getGameVote()
	CodeDataServer._likes = votes

	if not CodeDataServer._startupLikesLogged then
		CodeDataServer._startupLikesLogged = true
		warn(string.format("[CodeDataServer] Current game upVotes: %d", votes))
	end

	local released = {}
	local now = workspace:GetServerTimeNow()

	for code: string, info in pairs(CodeConfig.Codes) do
		local voteTarget = tonumber(info.voteTarget)
		local hasVoteGate = voteTarget ~= nil and voteTarget > 0
		local success, unlockedTick = CodeDataServer._baseDataWrapper:getAsync(code)
		if success then
			if not unlockedTick then
				if (not hasVoteGate) or (votes >= (voteTarget :: number)) then
					CodeDataServer._baseDataWrapper:setAsync(code, now)
					markReleased(released, code, now)
				end
			elseif isWithinExpiration(unlockedTick :: number) then
				markReleased(released, code, unlockedTick :: number)
			end
		end
	end

	CodeDataServer._releasedCodes = released

	NetSignals.getSignal(TriggerSignalCategory.Event.upVoteUpdate):Fire(released, votes)
end

function CodeDataServer.getReleaseCode()
	return CodeDataServer._releasedCodes, CodeDataServer._likes
end

function CodeDataServer.getReleasedList(): { string }
	local releasedMap, _likes = CodeDataServer.getReleaseCode()
	local seen: { [string]: boolean } = {}
	local list: { string } = {}

	for code, _unlockTick in pairs(releasedMap) do
		local normalized = normalizeCode(code)
		if not seen[normalized] and CodeConfig.Codes[normalized] then
			seen[normalized] = true
			table.insert(list, normalized)
		end
	end

	table.sort(list)
	return list
end

function CodeDataServer.isReleased(code: string): boolean
	local info = CodeConfig.Codes[normalizeCode(code)]
	if not info then
		return false
	end

	local voteTarget = tonumber(info.voteTarget)
	local hasVoteGate = voteTarget ~= nil and voteTarget > 0
	if not hasVoteGate then
		return true
	end

	local unlockedAt = getUnlockedAt(code)
	return unlockedAt ~= nil and isWithinExpiration(unlockedAt)
end

function CodeDataServer.canRedeem(code: string): (boolean, string)
	code = normalizeCode(code)
	local info = CodeConfig.Codes[code]
	if not info then
		return false, "Code unavailable"
	end

	local voteTarget = tonumber(info.voteTarget)
	local hasVoteGate = voteTarget ~= nil and voteTarget > 0
	if hasVoteGate and not CodeDataServer.isReleased(code) then
		return false, "Code locked"
	end

	local unlockedAt = getUnlockedAt(code)
	if hasVoteGate and unlockedAt then
		if not isWithinExpiration(unlockedAt) then
			return false, "Code expired!"
		end
	elseif hasVoteGate then
		return false, "Code locked"
	end

	return true, ""
end

function CodeDataServer._startAutoSaveLoop()
	setInterval(function()
		CodeDataServer.checkCodeRelease()
	end, AUTO_SAVE_INTERVAL)

	task.spawn(CodeDataServer.checkCodeRelease)
end

return CodeDataServer
