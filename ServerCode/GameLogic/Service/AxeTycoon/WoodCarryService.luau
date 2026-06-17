--!strict

--[[
	木头收集服务（服务端权威）。

	客户端每 CHECK_INTERVAL 秒统计检测范围内各木种数量并 fire WoodPickup(byCategory)；
	本服务按木种分别扣减堆叠区，再转入 PlayerData.AxeTycoon.carrying。
	客户端只销毁请求时记录的范围内模型，避免误删传送带上未进入范围的木头。

	堆叠区数据在 TycoonState（内存）；carrying 持久化在 PlayerData，掉线不丢。
	成功后广播 AxeTycoonSync { kind = "pickup", groundTotal }，供客户端移除视觉、对账清理幽灵模型并弹出 UI 飘字。
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ReplicatedCode = ReplicatedStorage:WaitForChild("ReplicatedCode")
local ServerCode = ServerScriptService:WaitForChild("ServerCode")

local Network = require(ReplicatedCode.Framework.Core.Network)
local WoodConfig = require(ReplicatedCode.GameLogic.Shared.Configs.WoodConfig)
local RemoteEventKey = require(ReplicatedCode.GameLogic.SharedConstants.Keys.RemoteEventKey)
local PlayerDataKey = require(ReplicatedCode.GameLogic.SharedConstants.Keys.PlayerDataKey)
local PlayerDataServer = require(ServerCode.Framework.DataStore.PlayerData.PlayerDataServer)
local BaseAssignmentService = require(ServerCode.GameLogic.Service.AxeTycoon.BaseAssignmentService)
local DebouncedPlayerSave = require(ServerCode.GameLogic.Modules.AxeTycoon.DebouncedPlayerSave)
local TycoonState = require(ServerCode.GameLogic.Modules.AxeTycoon.TycoonState)

-- 客户端请求去抖间隔（秒），与客户端检测周期一致
local CHECK_INTERVAL = 0.25

local WoodCarryService = {}

local started = false
local lastPickupAt: { [Player]: number } = {}

local function mergeCarrying(target: { [string]: number }, taken: { [string]: number })
	for category, count in taken do
		target[category] = (target[category] or 0) + count
	end
end

local function canPickup(player: Player): boolean
	if TycoonState.getGroundTotal(player.UserId) <= 0 then
		return false
	end

	local character = player.Character
	if not character then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		return false
	end

	return BaseAssignmentService.getBase(player) ~= nil
end

local function sanitizePickupRequest(requested: any): { [string]: number }?
	if type(requested) ~= "table" then
		return nil
	end

	local sanitized: { [string]: number } = {}
	for category, count in requested do
		if type(category) == "string" and WoodConfig.Woods[category] then
			local amount = math.floor(tonumber(count) or 0)
			if amount > 0 then
				sanitized[category] = amount
			end
		end
	end

	if next(sanitized) == nil then
		return nil
	end
	return sanitized
end

-- 下发拾取结果；groundTotal 供客户端与本地视觉数量对账，清理幽灵模型
local function firePickupSync(
	player: Player,
	base: Folder,
	taken: { [string]: number },
	silent: boolean?
)
	Network.fireClient(RemoteEventKey.AxeTycoonSync, player, {
		kind = "pickup",
		base = base,
		taken = taken,
		groundTotal = TycoonState.getGroundTotal(player.UserId),
		silent = silent,
	})
end

-- 按木种从堆叠区背走（与客户端范围内检测结果对应）
function WoodCarryService.pickupByCategory(player: Player, silent: boolean?, byCategory: { [string]: number })
	local sanitized = sanitizePickupRequest(byCategory)
	if not sanitized then
		return
	end

	local axeData = PlayerDataServer.getValue(player, PlayerDataKey.AxeTycoon)
	if type(axeData) ~= "table" then
		return
	end

	local base = BaseAssignmentService.getBase(player)
	if not base then
		return
	end

	local taken = TycoonState.takeGroundWoodByCategory(player.UserId, sanitized)
	if next(taken) == nil then
		firePickupSync(player, base, {}, silent)
		return
	end

	PlayerDataServer.updateValue(player, PlayerDataKey.AxeTycoon, function(data)
		data = if type(data) == "table" then data else {}
		local nextCarrying = if type(data.carrying) == "table" then data.carrying else {}
		mergeCarrying(nextCarrying, taken)
		data.carrying = nextCarrying
		return data
	end)
	DebouncedPlayerSave.schedule(player)
	firePickupSync(player, base, taken, silent)
end

-- 从堆叠区背走 count 件木头（按库存字典序扣减，供通行证等批量收取）
-- silent 为 true 时（如自动收集通行证）不下发拾取明细，客户端不弹飘字
-- matureOnly 为 true 时只背走「已落入堆叠区（成熟）」的木头，刚产出仍在飞行的不收
function WoodCarryService.pickup(player: Player, silent: boolean?, count: number?, matureOnly: boolean?)
	local groundTotal = if matureOnly
		then TycoonState.getMatureGroundTotal(player.UserId)
		else TycoonState.getGroundTotal(player.UserId)
	if groundTotal <= 0 then
		return
	end

	local axeData = PlayerDataServer.getValue(player, PlayerDataKey.AxeTycoon)
	if type(axeData) ~= "table" then
		return
	end

	local takeCount = math.clamp(count or 1, 1, groundTotal)
	local taken = if matureOnly
		then TycoonState.takeMatureGround(player.UserId, takeCount)
		else TycoonState.takeGroundWood(player.UserId, takeCount)
	if next(taken) == nil then
		return
	end

	PlayerDataServer.updateValue(player, PlayerDataKey.AxeTycoon, function(data)
		data = if type(data) == "table" then data else {}
		local nextCarrying = if type(data.carrying) == "table" then data.carrying else {}
		mergeCarrying(nextCarrying, taken)
		data.carrying = nextCarrying
		return data
	end)
	DebouncedPlayerSave.schedule(player)

	local base = BaseAssignmentService.getBase(player)
	if base then
		firePickupSync(player, base, taken, silent)
	end
end

local function onPickupRequested(player: Player, requestedByCategory: { [string]: number })
	local now = os.clock()
	local lastAt = lastPickupAt[player] or 0
	if now - lastAt < CHECK_INTERVAL then
		return
	end

	local sanitized = sanitizePickupRequest(requestedByCategory)
	if not sanitized then
		return
	end

	if not canPickup(player) then
		-- 服务端已无库存但客户端可能残留幽灵模型，静默对账
		if TycoonState.getGroundTotal(player.UserId) <= 0 then
			lastPickupAt[player] = now
			local base = BaseAssignmentService.getBase(player)
			if base then
				firePickupSync(player, base, {}, true)
			end
		end
		return
	end

	lastPickupAt[player] = now
	WoodCarryService.pickupByCategory(player, false, sanitized)
end

function WoodCarryService.start()
	if started then
		return
	end
	started = true

	Network.connectEvent(RemoteEventKey.WoodPickup, onPickupRequested, Network.t.table)
	Players.PlayerRemoving:Connect(function(player)
		lastPickupAt[player] = nil
	end)
end

return WoodCarryService
