--!strict

--[[
	离线木料服务（服务端权威）。

	玩家离线期间按「累计拥有斧头数 ownedAxeCount」累积离线木料（公式见 OfflineWoodConfig）：
	进服时据上次在线时间戳 offlineLastSeenAt 结算，累加到未领取池 pendingOfflineWood。

	领取方式（不走 UI）：客户端读 PlayerData.AxeTycoon.pendingOfflineWood，在基地 SpawnLocation
	附近生成木堆预制体；玩家触碰后 fire OfflineWoodClaim → 本服务把未领取木料一次性按 1:1
	转入处理机库存 processorStock（1 木料 = 1 现金价值），随后由 ProcessorService 每秒结算成现金。
	pendingOfflineWood 清零会随 PlayerData 同步回客户端，客户端据此移除木堆（无需额外同步事件）。

	防崩服误判：在线期间每 SEEN_FLUSH_INTERVAL 秒刷新 offlineLastSeenAt，玩家离开时再刷一次，
	避免把在线时间误计为离线。
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ReplicatedCode = ReplicatedStorage:WaitForChild("ReplicatedCode")
local ServerCode = ServerScriptService:WaitForChild("ServerCode")

local Network = require(ReplicatedCode.Framework.Core.Network)
local safePlayerAdded = require(ReplicatedCode.Framework.Utility.Player.SafePlayerAdded)
local setInterval = require(ReplicatedCode.Framework.Utility.Time.SetInterval)
local BaseConfig = require(ReplicatedCode.GameLogic.Shared.Configs.BaseConfig)
local OfflineWoodConfig = require(ReplicatedCode.GameLogic.Shared.Configs.OfflineWoodConfig)
local RemoteEventKey = require(ReplicatedCode.GameLogic.SharedConstants.Keys.RemoteEventKey)
local PlayerDataKey = require(ReplicatedCode.GameLogic.SharedConstants.Keys.PlayerDataKey)
local PlayerDataServer = require(ServerCode.Framework.DataStore.PlayerData.PlayerDataServer)
local DebouncedPlayerSave = require(ServerCode.GameLogic.Modules.AxeTycoon.DebouncedPlayerSave)

-- 在线期间刷新「上次在线时间戳」的间隔（秒），防止崩服把在线时间误判为离线
local SEEN_FLUSH_INTERVAL = 60

local OfflineWoodService = {}

local lastClaimAt: { [Player]: number } = {}
local started = false

-- 读取玩家 AxeTycoon 数据（非 table 返回 nil）
local function getAxeData(player: Player): { [string]: any }?
	local axeData = PlayerDataServer.getValue(player, PlayerDataKey.AxeTycoon)
	if type(axeData) ~= "table" then
		return nil
	end
	return axeData
end

-- 进服结算：据离线时长累加离线木料，并把时间戳推到当前
local function settleOnJoin(player: Player)
	local axeData = getAxeData(player)
	if not axeData then
		return
	end

	local now = os.time()
	local lastSeen = math.max(0, math.floor(tonumber(axeData.offlineLastSeenAt) or 0))
	local ownedAxeCount = math.max(0, math.floor(tonumber(axeData.ownedAxeCount) or 0))

	-- lastSeen == 0 表示新号/首次接入，本次不发奖，仅落地时间戳
	local reward = 0
	if lastSeen > 0 and now > lastSeen then
		reward = OfflineWoodConfig.compute(ownedAxeCount, now - lastSeen)
	end

	PlayerDataServer.updateValue(player, PlayerDataKey.AxeTycoon, function(data)
		data = if type(data) == "table" then data else {}
		if reward > 0 then
			data.pendingOfflineWood = math.max(0, math.floor(tonumber(data.pendingOfflineWood) or 0)) + reward
		end
		data.offlineLastSeenAt = now
		return data
	end)

	if reward > 0 then
		DebouncedPlayerSave.schedule(player)
	end
end

-- 刷新单个玩家的「上次在线时间戳」为当前时刻（不发奖）
local function flushLastSeen(player: Player)
	if not PlayerDataServer.hasLoaded(player) then
		return
	end
	PlayerDataServer.updateValue(player, PlayerDataKey.AxeTycoon, function(data)
		data = if type(data) == "table" then data else {}
		data.offlineLastSeenAt = os.time()
		return data
	end)
end

-- 领取：未领取离线木料一次性按 1:1 转入 processorStock，并清空未领取池
function OfflineWoodService.claim(player: Player)
	local axeData = getAxeData(player)
	if not axeData then
		return
	end
	local pending = math.max(0, math.floor(tonumber(axeData.pendingOfflineWood) or 0))
	if pending <= 0 then
		return
	end

	PlayerDataServer.updateValue(player, PlayerDataKey.AxeTycoon, function(data)
		data = if type(data) == "table" then data else {}
		local claimed = math.max(0, math.floor(tonumber(data.pendingOfflineWood) or 0))
		data.processorStock = (tonumber(data.processorStock) or 0) + claimed
		data.pendingOfflineWood = 0
		return data
	end)
	DebouncedPlayerSave.schedule(player)
end

-- 客户端触碰木堆 → 请求领取（带去抖，防刷）
local function onClaimRequested(player: Player)
	local now = os.clock()
	local last = lastClaimAt[player]
	if last and now - last < BaseConfig.BUTTON_DEBOUNCE then
		return
	end
	lastClaimAt[player] = now

	OfflineWoodService.claim(player)
end

function OfflineWoodService.start()
	if started then
		return
	end
	started = true

	-- 客户端领取请求
	Network.connectEvent(RemoteEventKey.OfflineWoodClaim, onClaimRequested)

	-- 在线期间周期刷新时间戳，避免在线时间被计为离线
	setInterval(function()
		for _, player in Players:GetPlayers() do
			flushLastSeen(player)
		end
	end, SEEN_FLUSH_INTERVAL)

	-- 进服：等数据加载后结算离线木料（pendingOfflineWood 经 PlayerData 同步给客户端驱动木堆）
	safePlayerAdded(function(player)
		PlayerDataServer.waitForDataLoadAsync(player)
		settleOnJoin(player)
	end)

	-- 离开：刷新时间戳，使下次进服从离开时刻起算离线；清理去抖记录
	Players.PlayerRemoving:Connect(function(player)
		flushLastSeen(player)
		lastClaimAt[player] = nil
	end)
end

return OfflineWoodService
