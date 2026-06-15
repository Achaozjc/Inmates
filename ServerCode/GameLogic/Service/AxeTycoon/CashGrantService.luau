--!strict

--[[
	付费金钱服务（服务端权威）。

	付费后立即发放现金 = 档位倍率 × 当前拥有斧头数（AxeTycoon.ownedAxeCount）。
	可重复购买的消耗型商品，无持久化档位；发放走 PlayerService.addCash（IAP 交易类型），
	随后调度落库。付费注册见 registerDevProducts，档位配置见 CashGrantConfig。
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ReplicatedCode = ReplicatedStorage:WaitForChild("ReplicatedCode")
local ServerCode = ServerScriptService:WaitForChild("ServerCode")

local CashGrantConfig = require(ReplicatedCode.GameLogic.Shared.Configs.CashGrantConfig)
local CashKey = require(ReplicatedCode.GameLogic.SharedConstants.Keys.CashKey)
local PlayerDataKey = require(ReplicatedCode.GameLogic.SharedConstants.Keys.PlayerDataKey)
local TransactionEnum = require(ReplicatedCode.GameLogic.SharedConstants.Enums.TransactionEnum)
local PlayerDataServer = require(ServerCode.Framework.DataStore.PlayerData.PlayerDataServer)
local PlayerService = require(ServerCode.GameLogic.Service.Sync.PlayerService)
local DebouncedPlayerSave = require(ServerCode.GameLogic.Modules.AxeTycoon.DebouncedPlayerSave)

local CashGrantService = {}

-- 读取玩家当前拥有斧头数（ownedAxeCount）
local function getOwnedAxeCount(player: Player): number
	local axeData = PlayerDataServer.getValue(player, PlayerDataKey.AxeTycoon)
	return if type(axeData) == "table" then (tonumber(axeData.ownedAxeCount) or 0) else 0
end

-- 发放指定档位现金（倍率 × 拥有斧头数）；付费回调据 productKey 反查 index 后调用。
-- 返回实际发放额（拥有斧头数为 0 时为 0，不发放）。
function CashGrantService.grant(player: Player, tierIndex: number): number
	local reward = CashGrantConfig.getReward(tierIndex, getOwnedAxeCount(player))
	if reward <= 0 then
		return 0
	end

	PlayerService.addCash(player, CashKey.Cash, reward, TransactionEnum.IAP, "PayCash")
	DebouncedPlayerSave.schedule(player)
	return reward
end

return CashGrantService
