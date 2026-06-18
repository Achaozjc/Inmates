local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local AttributeEnum = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Enums.AttributeEnum)
local retryAsync = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Common.RetryAsync)
local PlayerDataServer = require(ServerScriptService.ServerCode.Framework.DataStore.PlayerData.PlayerDataServer)

local Network = require(ReplicatedStorage.ReplicatedCode.Framework.Core.Network)
local RemoteEventName = require(ReplicatedStorage.ReplicatedCode.Framework.Core.Network.RemoteName.RemoteEventName)
local PlaceId = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Misc.PlaceId)
local t = Network.t

local ATTEMPT_LIMIT = 5
local RETRY_DELAY = 1
local RETRY_EXPONENT = 1
local FLOOD_DELAY = 10

type Callback = (...any) -> ...any

local TeleportManager = {}
local beforeAfkTeleportCallbacks: { (Player) -> boolean? } = {}

local function SafeTeleport(players: { Player }, placeId: number, options: TeleportOptions?, teleportData: any?)
    local saveSuccess = TeleportManager.tagTeleport(players, true)
    if not saveSuccess then
        TeleportManager.tagTeleport(players)
        warn("[TeleportManager] Teleport cancelled because player data save failed.")
        return false, "Player data save failed"
    end

    Network.fireClientFor(RemoteEventName.Teleport_Gui, players, true)

    local success, result = retryAsync(function()
        return TeleportService:TeleportAsync(placeId, players, options) -- teleport the user in a protected call to prevent erroring在受保护的调用中传送用户，以防止出错
    end, ATTEMPT_LIMIT, RETRY_DELAY, RETRY_EXPONENT)

    if not success then
        warn(result) -- print the failure reason to output将失败原因打印输出
    end

    return success, result
end

--function TeleportManager.retry(players)
--	local placeId = PlaceId.GamePlace
--	TeleportManager.ReserveTeleport(players, placeId)
--end

function TeleportManager.returnLobby(players)
    local placeId = PlaceId.Lobby
    SafeTeleport(players, placeId)
end

function TeleportManager.tagTeleport(players: { Player }, bool: boolean?): boolean
    local allSaved = true
    for _, plr in pairs(players) do
        plr:SetAttribute(AttributeEnum.Teleproting, bool or nil)
        -- 传送前保存一次；canSave 为 false（如 Studio 禁用 DataStore）时静默跳过
        if bool and PlayerDataServer.canSave(plr) then
            local success, result = PlayerDataServer.saveDataAsync(plr)
            if not success then
                allSaved = false
                warn("[TeleportManager] Failed to save before teleport:", plr.UserId, result)
            end
        elseif bool then
            allSaved = false
            warn("[TeleportManager] Cannot save before teleport:", plr.UserId)
        end
    end
    return allSaved
end

function TeleportManager.ReserveTeleport(players: { Player }, placeId: number, teleportData: any?)
    if not next(players) then
        return
    end
    local reservedServerCode = RunService:IsStudio() and 100000000000 or TeleportService:ReserveServerAsync(placeId)
    local teleportOptions = Instance.new("TeleportOptions")
    if teleportData then
        teleportOptions:SetTeleportData(teleportData)
    end
    teleportOptions.ReservedServerAccessCode = reservedServerCode
    SafeTeleport(players, placeId, teleportOptions, teleportData)
end

-- 若项目中有「排除正在回大厅的玩家」需求，可取消注释并配合 AttributeEnum 使用
-- local function getPlayers()
-- 	local playerList = {}
-- 	for _, plr in ipairs(Players:GetPlayers()) do
-- 		if not plr:GetAttribute("returnLobby") then
-- 			table.insert(playerList, plr)
-- 		end
-- 	end
-- 	return playerList
-- end

function TeleportManager.followPlayer(player: Player, followName: string)
    -- 使用 task.spawn 防止网络请求阻塞主线程
    task.spawn(function()
        local followId: number
        pcall(function() -- This call can fail sometimes!
            followId = Players:GetUserIdFromNameAsync(followName) -- Fetch ID from name
        end)
        if followId and followId ~= 0 then
            -- GetPlayerPlaceInstanceAsync 返回 (placeId, jobId)，pcall 成功时为 (true, placeId, jobId)
            local success, errorMessage, _currentInstance, placeId, jobId = pcall(function()
                return TeleportService:GetPlayerPlaceInstanceAsync(followId)
            end)
            if success and placeId and jobId then
                TeleportService:TeleportToPlaceInstance(placeId, jobId, player)
            elseif not success then
                warn(errorMessage, placeId) -- 失败时 placeId 为错误信息
            end
        else
            warn("Player " .. player.UserId .. " is not following another player!")
        end
    end)
end

function TeleportManager.getPlayerPlaceInstanceAsync(userId: number)
    --local success, errorMessage, _currentInstance, placeId, jobId = retryAsync(function()
    --	return TeleportService:GetPlayerPlaceInstanceAsync(userId)
    --end, ATTEMPT_LIMIT, RETRY_DELAY, FLOOD_DELAY)
    local success, _errorMessage, _currentInstance, placeId, jobId = pcall(function()
        -- followId is the user ID of the player that you want to retrieve the place and job ID for
        return TeleportService:GetPlayerPlaceInstanceAsync(userId)
    end)
    return success, placeId, jobId
end

local function handleFailedTeleport(
    player,
    teleportResult: Enum.TeleportResult,
    errorMessage: string,
    targetPlaceId: number,
    teleportOptions: TeleportOptions?
)
    if teleportResult == Enum.TeleportResult.Flooded then
        task.wait(FLOOD_DELAY)
    elseif teleportResult == Enum.TeleportResult.Failure then
        task.wait(RETRY_DELAY)
    else
        -- 如果传送无效，则报告错误而不是重试
        error(
            ("Invalid teleport [%s]: %s placeId: %s"):format(teleportResult.Name, errorMessage, tostring(targetPlaceId))
        )
    end

    Network.fireClient(RemoteEventName.Teleport_Gui, player, false)
    TeleportManager.tagTeleport({ player })

    SafeTeleport({ player }, targetPlaceId, teleportOptions)
end

function TeleportManager.afk(players)
    if not next(players) then
        return
    end
    local teleportOptions = Instance.new("TeleportOptions")
    teleportOptions:SetTeleportData({ afk = true }) -- 可选，标记为AFK返回

    -- 任一 before 回调失败仍然必须传送：取消会让玩家被 Roblox 默认 20min 空闲踢出，
    -- 失去 AFK 数据后果远大于"少存一次自动保存信息"。
    local prepFailed = false
    for _, player in ipairs(players) do
        if not TeleportManager.runBeforeAfkTeleport(player) then
            prepFailed = true
            warn("[TeleportManager] AFK teleport before-callback failed but will continue:", player.UserId)
        end
    end

    local ok = SafeTeleport(players, PlaceId.Lobby, teleportOptions)
    if not ok and prepFailed then
        warn("[TeleportManager] AFK teleport SafeTeleport also failed after prep failure")
    end
end

function TeleportManager.registerBeforeAfkTeleport(callback: (Player) -> boolean?)
	table.insert(beforeAfkTeleportCallbacks, callback)
end

function TeleportManager.runBeforeAfkTeleport(player: Player): boolean
	local allPrepared = true
	for _, callback in ipairs(beforeAfkTeleportCallbacks) do
		local ok, result = pcall(callback, player)
		if not ok then
			allPrepared = false
			warn("[TeleportManager] before AFK teleport callback failed:", result)
		elseif result == false then
			allPrepared = false
			warn("[TeleportManager] before AFK teleport callback rejected:", player.UserId)
		end
	end
	return allPrepared
end

function TeleportManager.start()
    TeleportService.TeleportInitFailed:Connect(handleFailedTeleport)

    --选择去向
    Network.connectEvent(RemoteEventName.Teleport_Select, function(player: Player, key)
        if player:GetAttribute(AttributeEnum.Teleproting) then
            return
        end
        if key == "AFK" then
            TeleportManager.afk({ player })
            return
        end
        TeleportManager.returnLobby({ player })
    end, t.string)
end

return TeleportManager
