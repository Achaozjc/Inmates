--!strict
local AvatarEditorService = game:GetService("AvatarEditorService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ExperienceNotificationService = game:GetService("ExperienceNotificationService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")
local GroupService = game:GetService("GroupService")
local RunService = game:GetService("RunService")

local TimeTokenCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.TimeTokenCategory)
local NotifyCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.NotifyCategory)
local TriggerSignalCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.TriggerSignalCategory)
local Network = require(ReplicatedStorage.ReplicatedCode.Framework.Core.Network)
local NetSignals = require(ReplicatedStorage.ReplicatedCode.Framework.Core.Network.NetSignals)
local RemoteEventKey = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.RemoteEventKey)
local PlayerDataClient = require(ReplicatedStorage.ReplicatedCode.Framework.DataStore.PlayerDataClient)
local PlayerDataKey = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.PlayerDataKey)

local GroupId = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Misc.GroupId)

local setInterval = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Time.SetInterval)

local placeId = game.PlaceId

local localPlayer = Players.LocalPlayer :: Player

local SocialManager = {}
SocialManager.clear = nil :: (() -> nil)?
local _favoritePromptConnection = nil :: RBXScriptConnection?
local _eventRsvpStatusCache: { [string]: any } = {}
local _experienceEventInfoCache: { [string]: any } = {}

local DIRECT_JOIN_URL = "https://www.roblox.com/games/start?placeId=%d&launchData=%s" :: any
local EVENT_QUERY_FAILURE_RETRY_SECONDS = 30
local EVENT_QUERY_WARN_COOLDOWN_SECONDS = 60
-- 原生邀请面板关闭后短时间内重复弹出会严重影响移动端体验
local INVITE_PROMPT_COOLDOWN_SECONDS = 60

local InviteOptions = Instance.new("ExperienceInviteOptions")
local lastInvitePromptAt = 0
InviteOptions.PromptMessage = "Invite friends to get boosts!!"

local LAUNCH_DATA = {
    referrerId = localPlayer.UserId,
}

InviteOptions.LaunchData = HttpService:JSONEncode(LAUNCH_DATA)

function SocialManager.joinCommunity()
    -- This should be done in a script running on the client
    local success, result = pcall(function()
        return GroupService:PromptJoinAsync(GroupId)
    end)

    if success then
        if result == Enum.GroupMembershipStatus.Joined then
            print("Player joined the group!")
        elseif result == Enum.GroupMembershipStatus.JoinRequestPending then
            print("Join request sent")
        elseif result == Enum.GroupMembershipStatus.AlreadyMember then
            print("Already a member")
        else
            print("Did not join or not eligible")
        end
        return result
    else
        warn("Prompt failed:", result)
    end
    return nil
end

-- Function to check whether the player can send an invite
local function canSendGameInvite(sendingPlayer, receiverUserID: number?)
    local success, canSend = pcall(function()
        return SocialService:CanSendGameInviteAsync(sendingPlayer, receiverUserID)
    end)
    return success and canSend
end

-- Function to check whether the player can be prompted to enable notifications
function SocialManager.canPromptOptIn()
    local success, canPrompt = pcall(function()
        return ExperienceNotificationService:CanPromptOptInAsync()
    end)
    return success and canPrompt
end

function SocialManager.getFavorite()
    local success, favorite = pcall(function()
        return AvatarEditorService:GetFavoriteAsync(placeId, Enum.AvatarItemType.Asset)
    end)

    return success and favorite
end

function SocialManager.PromptOptIn()
    local canPrompt = SocialManager.canPromptOptIn()

    if canPrompt then
        pcall(function()
            ExperienceNotificationService:PromptOptIn()
        end)
    end

    local Info = PlayerDataClient.get(PlayerDataKey.Info)
    if not Info.favorite then
        if _favoritePromptConnection then
            _favoritePromptConnection:Disconnect()
            _favoritePromptConnection = nil
        end
        -- 回调参数为 Enum.AvatarPromptResult（Success/PermissionDenied/Failed），部分环境可能拿不到；这里只要玩家操作过就通知服务端
        _favoritePromptConnection = AvatarEditorService.PromptSetFavoriteCompleted:Once(function()
            _favoritePromptConnection = nil
            -- if result == Enum.AvatarPromptResult.Success then
            -- 	Network.fireServer(RemoteEventKey.SetFavorite)
            -- end
            Network.fireServer(RemoteEventKey.SetFavorite)
        end)
        pcall(function()
            AvatarEditorService:PromptSetFavorite(placeId, Enum.AvatarItemType.Asset, true)
        end)
    end

    if SocialManager.clear and not canPrompt and Info.favorite then --  (isFavorite) and
        SocialManager.clear()
        SocialManager.clear = nil
    end
end

function SocialManager.OpenGameInvite()
    local now = os.clock()
    if now - lastInvitePromptAt < INVITE_PROMPT_COOLDOWN_SECONDS then
        return
    end

    local canInvite = canSendGameInvite(localPlayer)
    if canInvite then
        lastInvitePromptAt = now
        local ok, err = pcall(function()
            SocialService:PromptGameInvite(localPlayer, InviteOptions)
        end)
        if not ok then
            warn("[SocialManager] PromptGameInvite 失败：", err)
        end
    elseif RunService:IsStudio() then
        NetSignals.getSignal(TriggerSignalCategory.Client.notify):Fire(
            "Invite unavailable in Studio - test on a published client",
            NotifyCategory.Warn
        )
    end
end

function SocialManager.initInviteCode()
    local jsonEncodedData = HttpService:JSONEncode(LAUNCH_DATA)
    local urlEncodedData = HttpService:UrlEncode(jsonEncodedData) :: any
    return string.format(DIRECT_JOIN_URL, tostring(placeId), urlEncodedData)
end

function SocialManager.checkRsvpStatus(rsvpStatus: Enum.RsvpStatus)
    if rsvpStatus == Enum.RsvpStatus.Going then
        return true --表示已关注
    end
    return false
end

function SocialManager.getEventRsvpStatus(eventId: string, sourceTag: string?)
    local cacheKey = tostring(eventId)
    local cached = _eventRsvpStatusCache[cacheKey]
    if cached then
        if cached.status ~= nil then
            return cached.status
        end
        if os.clock() < (cached.retryAt or 0) then
            return nil
        end
    end

    local success, currentRsvpStatus = pcall(function()
        return SocialService:GetEventRsvpStatusAsync(eventId)
    end)

    local now = os.clock()
    if not success then
        cached = cached or {}
        local lastWarnAt = cached.lastWarnAt or 0
        if now - lastWarnAt >= EVENT_QUERY_WARN_COOLDOWN_SECONDS then
            warn(
                string.format(
                    "Failed to get RSVP status (eventId=%s, source=%s): %s",
                    tostring(eventId),
                    tostring(sourceTag or "unknown"),
                    tostring(currentRsvpStatus)
                )
            )
            cached.lastWarnAt = now
        end
        cached.retryAt = now + EVENT_QUERY_FAILURE_RETRY_SECONDS
        _eventRsvpStatusCache[cacheKey] = cached
        return cached.status
    end
    _eventRsvpStatusCache[cacheKey] = {
        status = currentRsvpStatus,
        retryAt = 0,
        lastWarnAt = cached and cached.lastWarnAt or 0,
    }
    return currentRsvpStatus
end

-- Lifecycle for experience events (HasStarted / HasEnded). Nil if the request failed or event is unknown.
function SocialManager.getExperienceEventInfo(eventId: string): any
    local cacheKey = tostring(eventId)
    local cached = _experienceEventInfoCache[cacheKey]
    if cached then
        if cached.info ~= nil then
            return cached.info
        end
        if os.clock() < (cached.retryAt or 0) then
            return nil
        end
    end

    local success, info = pcall(function()
        return SocialService:GetExperienceEventAsync(eventId)
    end)
    if success and type(info) == "table" then
        _experienceEventInfoCache[cacheKey] = {
            info = info,
            retryAt = 0,
        }
        return info
    end
    _experienceEventInfoCache[cacheKey] = {
        info = nil,
        retryAt = os.clock() + EVENT_QUERY_FAILURE_RETRY_SECONDS,
    }
    return nil
end

-- 弹出 Roblox 活动 RSVP 面板（EventGui Notify Me 按钮，移植自 dingdong SocialManager.followEvent）
function SocialManager.followEvent(eventId: string): Enum.RsvpStatus?
    local success, rsvpStatus = pcall(function()
        return SocialService:PromptRsvpToEventAsync(eventId)
    end)
    if success then
        _eventRsvpStatusCache[tostring(eventId)] = {
            status = rsvpStatus,
            retryAt = 0,
            lastWarnAt = 0,
        }
        return rsvpStatus
    end
    return nil
end

function SocialManager.promptEventSubscribe(eventId: string): (boolean, Enum.RsvpStatus?, string?)
    -- 检查是否已订阅，如果已订阅则直接返回，避免弹出取消订阅的面板
    local currentStatus = SocialManager.getEventRsvpStatus(eventId, "promptEventSubscribe")
    if SocialManager.checkRsvpStatus(currentStatus) then
        return true, currentStatus, nil
    end

    local success, result = pcall(function()
        return SocialService:PromptRsvpToEventAsync(eventId)
    end)
    if not success then
        warn("Failed to prompt event subscribe:", result)
        local resultText = tostring(result)
        if string.find(resultText, "Event has already started", 1, true) then
            NetSignals.getSignal(TriggerSignalCategory.Client.notify):Fire("Event is running now", NotifyCategory.Warn)
            return false, nil, "EventStarted"
        end
        return false, nil, nil
    end
    _eventRsvpStatusCache[tostring(eventId)] = {
        status = result,
        retryAt = 0,
        lastWarnAt = 0,
    }
    return true, result, nil
end

local function checkFriend(player: Player)
    local isFriend = player:IsFriendsWithAsync(localPlayer.UserId)
    if isFriend then
        Network.fireServer(RemoteEventKey.FriendLuck)
    end
end

function SocialManager.sendFriendRequest(player: Player)
    StarterGui:SetCore("PromptSendFriendRequest", player)
end

function SocialManager.setup()
    SocialManager.clear = setInterval(function()
        SocialManager.PromptOptIn()
    end, TimeTokenCategory.minutes * 1)

    Players.PlayerAdded:Connect(checkFriend)
    Players.PlayerRemoving:Connect(function()
        Network.fireServer(RemoteEventKey.FriendLuck)
    end)

    Network.fireServer(RemoteEventKey.FriendLuck)
end

return SocialManager
