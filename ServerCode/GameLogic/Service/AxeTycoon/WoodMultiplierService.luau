--!strict

--[[
	全服木料倍率服务（服务端权威）。

	每 REFRESH_INTERVAL 秒在 [MIN, MAX] 内随机刷新一次倍率；
	仅影响玩家触碰 Storage 入库时的换算（背负 Wood × 倍率 → processorStock），
	不影响产木、背负显示及每秒 PendingCash 结算。
	同步：AxeTycoonSync { kind = "multiplier" } + Workspace 属性（供 UI 与晚加入玩家读取）。
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Network = require(ReplicatedStorage.ReplicatedCode.Framework.Core.Network)
local safePlayerAdded = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Player.SafePlayerAdded)
local setInterval = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Time.SetInterval)
local WoodMultiplierConfig = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Configs.WoodMultiplierConfig)
local RemoteEventKey = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.RemoteEventKey)

local WoodMultiplierService = {}

local currentMultiplier = WoodMultiplierConfig.MIN
local nextRefreshAt = 0
local started = false

local function rollMultiplier(): number
	local minValue = WoodMultiplierConfig.MIN
	local maxValue = WoodMultiplierConfig.MAX
	local raw = minValue + (maxValue - minValue) * math.random()
	return WoodMultiplierConfig.quantize(raw)
end

local function buildSyncPayload(): { kind: string, multiplier: number, nextRefreshAt: number }
	return {
		kind = "multiplier",
		multiplier = currentMultiplier,
		nextRefreshAt = nextRefreshAt,
	}
end

local function syncWorldState()
	Workspace:SetAttribute(WoodMultiplierConfig.ATTR_MULTIPLIER, currentMultiplier)
	Workspace:SetAttribute(WoodMultiplierConfig.ATTR_NEXT_REFRESH_AT, nextRefreshAt)
end

local function broadcastState()
	syncWorldState()
	Network.fireAllClients(RemoteEventKey.AxeTycoonSync, buildSyncPayload())
end

local function refreshMultiplier()
	currentMultiplier = rollMultiplier()
	nextRefreshAt = Workspace:GetServerTimeNow() + WoodMultiplierConfig.REFRESH_INTERVAL
	broadcastState()
end

function WoodMultiplierService.getMultiplier(): number
	return currentMultiplier
end

function WoodMultiplierService.getNextRefreshAt(): number
	return nextRefreshAt
end

function WoodMultiplierService.syncPlayer(player: Player)
	Network.fireClient(RemoteEventKey.AxeTycoonSync, player, buildSyncPayload())
end

function WoodMultiplierService.start()
	if started then
		return
	end
	started = true

	refreshMultiplier()
	setInterval(refreshMultiplier, WoodMultiplierConfig.REFRESH_INTERVAL)

	safePlayerAdded(function(player)
		WoodMultiplierService.syncPlayer(player)
	end)
end

return WoodMultiplierService
