--!strict

--[[
	兑换码服务端：拉取解锁状态、兑换发奖、向客户端推送点赞解锁更新。
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Network = require(ReplicatedStorage.ReplicatedCode.Framework.Core.Network)
local NetSignals = require(ReplicatedStorage.ReplicatedCode.Framework.Core.Network.NetSignals)
local PlayerDataServer = require(ServerScriptService.ServerCode.Framework.DataStore.PlayerData.PlayerDataServer)
local CodeDataServer = require(ServerScriptService.ServerCode.GameLogic.DataStore.CodeDataServer)
local CodeConfig = require(ServerScriptService.ServerCode.GameLogic.DataStore.CodeConfig)
local CodeRewardConfig = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Configs.CodeRewardConfig)
local PlayerService = require(ServerScriptService.ServerCode.GameLogic.Service.Sync.PlayerService)

local RemoteFunctionKey = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.RemoteFunctionKey)
local RemoteEventKey = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.RemoteEventKey)
local PlayerDataKey = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.PlayerDataKey)
local TriggerSignalCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.TriggerSignalCategory)
local TransactionEnum = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Enums.TransactionEnum)

local CodeService = {}

local lastCallAt: { [Player]: { [string]: number } } = {}

local function normalizeCode(code: string): string
	return string.lower(code)
end

local function getOwnedAxeCount(player: Player): number
	local axeData = PlayerDataServer.getValue(player, PlayerDataKey.AxeTycoon)
	return if type(axeData) == "table" then (tonumber(axeData.ownedAxeCount) or 0) else 0
end

local function checkCooldown(player: Player, key: string, seconds: number): boolean
	local now = os.clock()
	local playerTimes = lastCallAt[player]
	if not playerTimes then
		playerTimes = {}
		lastCallAt[player] = playerTimes
	end

	local last = playerTimes[key] or 0
	if now - last < seconds then
		return false
	end

	playerTimes[key] = now
	return true
end

local function buildPayload()
	return {
		released = CodeDataServer.getReleasedList(),
		likes = CodeDataServer._likes,
	}
end

local function broadcastReleaseUpdate()
	local payload = buildPayload()
	Network.fireAllClients(
		RemoteEventKey.Code_ReleaseUpdate,
		payload.released,
		payload.likes
	)
end

local function handleGetReleased(_player: Player): (boolean, any)
	if not checkCooldown(_player, "Code_GetReleased", 30) then
		return false, "too_fast"
	end

	return true, buildPayload()
end

local function handleRedeem(player: Player, code: any): (boolean, string)
	if not checkCooldown(player, "Code_Redeem", 0.5) then
		return false, "Too fast"
	end

	if not PlayerDataServer.hasLoaded(player) then
		return false, "Please wait"
	end

	if typeof(code) ~= "string" or code == "" then
		return false, "Invalid code"
	end

	code = normalizeCode(code)
	local codeInfo = CodeConfig.Codes[code]
	if not codeInfo then
		return false, "Code unavailable"
	end

	local canRedeem, reason = CodeDataServer.canRedeem(code)
	if not canRedeem then
		return false, reason
	end

	local redeemed = PlayerDataServer.getValue(player, PlayerDataKey.Codes) or {}
	if table.find(redeemed, code) then
		return false, "Code used"
	end

	local resolvedRewards = CodeRewardConfig.resolveRewards(codeInfo.rewards, getOwnedAxeCount(player))
	if #resolvedRewards == 0 then
		return false, "No reward available"
	end

	table.insert(redeemed, code)
	PlayerDataServer.setValue(player, PlayerDataKey.Codes, redeemed)

	PlayerService.getRewards(player, resolvedRewards, TransactionEnum.Code, code)

	print(string.format("[CodeService] %s redeemed code=%s", player.Name, code))
	return true, "Success"
end

function CodeService.start()
	Network.bindFunction(RemoteFunctionKey.Code_GetReleased, handleGetReleased)
	Network.bindFunction(RemoteFunctionKey.Code_Redeem, handleRedeem)

	NetSignals.getSignal(TriggerSignalCategory.Event.upVoteUpdate).Event:Connect(function()
		broadcastReleaseUpdate()
	end)

	Players.PlayerAdded:Connect(function(player)
		task.defer(function()
			if player.Parent then
				local payload = buildPayload()
				Network.fireClient(
					RemoteEventKey.Code_ReleaseUpdate,
					player,
					payload.released,
					payload.likes
				)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastCallAt[player] = nil
	end)
end

function CodeService.listen() end

return CodeService
