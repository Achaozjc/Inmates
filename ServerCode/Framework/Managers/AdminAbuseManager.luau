--!strict

local RunService = game:GetService("RunService")
local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")

local AdminAbuseConfig = require(ReplicatedStorage.ReplicatedCode.Framework.AdminAbuse.AdminAbuseConfig)
local Network = require(ReplicatedStorage.ReplicatedCode.Framework.Core.Network)
local RemoteEventKey = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.RemoteEventKey)

local AdminAbuseManager = {}

local IS_STUDIO = RunService:IsStudio()
local DEV_ACTIVITY_TOPIC = "GlobalDevActivity"
local MESSAGE_TOPIC = "GlobalMessages"
local DATA_STORE_KEY = "CurrentDevActivity"
local activeAttribute = AdminAbuseConfig.ReplicatedActiveDevActivityAttribute
local activityStore: GlobalDataStore? = nil

local lastMessageId: string? = nil
local lastAppliedActivity = ""
local activeCancelTask: thread? = nil

local function getRemoteEventName(key: string): string?
	local value = (RemoteEventKey :: any)[key]
	if type(value) ~= "string" then
		warn("[AdminAbuseManager] Missing RemoteEventKey." .. key)
		return nil
	end
	return value
end

local function fireAllClients(key: string, ...: any)
	local eventName = getRemoteEventName(key)
	if eventName then
		Network.fireAllClients(eventName, ...)
	end
end

local function sendGlobalMessage(userId: number, message: string)
	fireAllClients("GlobalMessage", userId, message)
end

local function parseStoredActivity(saved: any): (string, number?)
	if type(saved) ~= "string" or saved == "" then
		return "", nil
	end

	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, saved)
	if ok and type(decoded) == "table" then
		local activityId = (decoded :: any).DevActivity
		local expiresAt = (decoded :: any).ExpiresAt
		local parsedActivityId = if type(activityId) == "string" then activityId else ""
		local parsedExpiresAt = if type(expiresAt) == "number" then expiresAt else nil
		return parsedActivityId, parsedExpiresAt
	end

	if AdminAbuseConfig.DevActivities[saved] then
		return saved, nil
	end
	return "", nil
end

local function getActivityStore(): GlobalDataStore?
	if activityStore then
		return activityStore
	end

	local ok, store = pcall(function()
		return DataStoreService:GetDataStore("GlobalDevActivityStore")
	end)
	if not ok then
		warn("[AdminAbuseManager] DataStore unavailable:", store)
		return nil
	end

	activityStore = store
	return store
end

local function applyActivity(activityId: string?)
	local nextActivity = activityId or ""
	if nextActivity == lastAppliedActivity then
		return
	end

	lastAppliedActivity = nextActivity
	ReplicatedStorage:SetAttribute(activeAttribute, nextActivity)
	fireAllClients("AdminEventChanged", nextActivity)
end

local function saveActivity(activityId: string?, expiresAtUnix: number?)
	if IS_STUDIO then
		return
	end

	local value = ""
	if activityId and activityId ~= "" then
		if type(expiresAtUnix) == "number" and expiresAtUnix > 0 then
			value = HttpService:JSONEncode({
				DevActivity = activityId,
				ExpiresAt = math.floor(expiresAtUnix),
			})
		else
			value = activityId
		end
	end

	task.spawn(function()
		local store = getActivityStore()
		if not store then
			return
		end

		for attempt = 1, 3 do
			local ok, err = pcall(function()
				store:SetAsync(DATA_STORE_KEY, value)
			end)
			if ok then
				return
			end
			warn("[AdminAbuseManager] Save failed:", attempt, err)
			task.wait(2)
		end
	end)
end

local function publishActivity(activityId: string, expiresAtUnix: number?)
	if IS_STUDIO then
		return
	end

	local payload: { DevActivity: string, ExpiresAt: number? } = {
		DevActivity = activityId,
	}
	if activityId ~= "" and type(expiresAtUnix) == "number" and expiresAtUnix > 0 then
		payload.ExpiresAt = math.floor(expiresAtUnix)
	end

	local ok, err = pcall(function()
		MessagingService:PublishAsync(DEV_ACTIVITY_TOPIC, HttpService:JSONEncode(payload))
	end)
	if not ok then
		warn("[AdminAbuseManager] Publish activity failed:", err)
	end
end

local function cancelScheduledActivityExpiry()
	if activeCancelTask then
		task.cancel(activeCancelTask)
		activeCancelTask = nil
	end
end

local function revertTimedActivity(reason: string?)
	saveActivity("")
	publishActivity("", nil)
	applyActivity("")
	print("[AdminAbuseManager] Dev activity reverted" .. (reason and (" (" .. reason .. ")") or "") .. ".")
end

local function scheduleActivityExpiryAt(expiresAtUnix: number)
	cancelScheduledActivityExpiry()

	local remain = math.floor(expiresAtUnix) - os.time()
	if remain <= 0 then
		revertTimedActivity("已过期")
		return
	end

	activeCancelTask = task.delay(remain, function()
		activeCancelTask = nil
		revertTimedActivity("定时结束")
	end)
end

local function applyPublishedActivity(activityId: string, expiresAtUnix: number?)
	cancelScheduledActivityExpiry()

	if activityId == "" then
		applyActivity("")
		return
	end

	if not AdminAbuseConfig.DevActivities[activityId] then
		applyActivity("")
		return
	end

	if expiresAtUnix and expiresAtUnix <= os.time() then
		applyActivity("")
		return
	end

	applyActivity(activityId)
	if expiresAtUnix and expiresAtUnix > os.time() then
		scheduleActivityExpiryAt(expiresAtUnix)
	end
end

local function onCrossServerActivityMessage(message: { Data: string })
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, message.Data)
	if not ok or type(decoded) ~= "table" then
		return
	end

	local activityId = (decoded :: any).DevActivity
	if type(activityId) ~= "string" then
		return
	end

	local expiresAt = (decoded :: any).ExpiresAt
	applyPublishedActivity(activityId, if type(expiresAt) == "number" then expiresAt else nil)
end

local function loadSavedActivity()
	if IS_STUDIO then
		applyActivity("")
		return
	end

	task.spawn(function()
		local store = getActivityStore()
		if not store then
			applyActivity("")
			return
		end

		local saved: any = nil
		for attempt = 1, 3 do
			local ok, result = pcall(function()
				return store:GetAsync(DATA_STORE_KEY)
			end)
			if ok then
				saved = result
				break
			end
			warn("[AdminAbuseManager] Load failed:", attempt, result)
			task.wait(2)
		end

		local activityId, expiresAt = parseStoredActivity(saved)
		applyPublishedActivity(activityId, expiresAt)
	end)
end

local function listenCrossServerMessages()
	if IS_STUDIO then
		return
	end

	MessagingService:SubscribeAsync(DEV_ACTIVITY_TOPIC, onCrossServerActivityMessage)

	MessagingService:SubscribeAsync(MESSAGE_TOPIC, function(message)
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, message.Data)
		if not ok or type(decoded) ~= "table" then
			return
		end
		if decoded.Id == lastMessageId then
			return
		end
		lastMessageId = decoded.Id
		sendGlobalMessage(decoded.UserId, decoded.Message)
	end)
end

local function listenAdminActivityCommand()
	local eventName = getRemoteEventName("AdminEventCommand")
	if not eventName then
		return
	end

	Network.connectEvent(eventName, function(player: Player, arg: string, duration: any)
		if not AdminAbuseConfig.IsAdmin(player.UserId) or type(arg) ~= "string" then
			return
		end

		local lower = arg:lower()
		local resolvedId = ""
		if lower ~= "off" then
			for key in pairs(AdminAbuseConfig.DevActivities) do
				if key:lower() == lower then
					resolvedId = key
					break
				end
			end
			if resolvedId == "" then
				warn("[AdminAbuseManager] Unknown dev activity:", arg)
				return
			end
		end

		local expiresAtUnix: number? = nil
		if resolvedId ~= "" and type(duration) == "number" and duration > 0 then
			expiresAtUnix = os.time() + math.floor(duration)
		end

		cancelScheduledActivityExpiry()
		saveActivity(resolvedId, expiresAtUnix)
		publishActivity(resolvedId, expiresAtUnix)
		applyActivity(resolvedId)

		if expiresAtUnix and expiresAtUnix > os.time() then
			scheduleActivityExpiryAt(expiresAtUnix)
		end
	end)
end

local function listenGlobalMessageCommand()
	local eventName = getRemoteEventName("GlobalMessageCommand")
	if not eventName then
		return
	end

	Network.connectEvent(eventName, function(player: Player, message: string, delayMins: any)
		if not AdminAbuseConfig.IsAdmin(player.UserId) then
			return
		end
		if type(message) ~= "string" or message == "" then
			return
		end

		local function send()
			local messageId = HttpService:GenerateGUID(false)
			lastMessageId = messageId

			if not IS_STUDIO then
				local ok, err = pcall(function()
					MessagingService:PublishAsync(MESSAGE_TOPIC, HttpService:JSONEncode({
						UserId = player.UserId,
						Message = message,
						Id = messageId,
					}))
				end)
				if not ok then
					warn("[AdminAbuseManager] Publish message failed:", err)
				end
			end

			sendGlobalMessage(player.UserId, message)
		end

		local minutes = tonumber(delayMins) or 0
		if minutes > 0 then
			task.delay(minutes * 60, send)
		else
			send()
		end
	end)
end

function AdminAbuseManager.start()
	loadSavedActivity()
	listenCrossServerMessages()
	listenAdminActivityCommand()
	listenGlobalMessageCommand()
end

return AdminAbuseManager
