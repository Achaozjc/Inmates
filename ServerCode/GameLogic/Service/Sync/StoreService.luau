--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ReplicatedCode = ReplicatedStorage:WaitForChild("ReplicatedCode")
local ServerCode = ServerScriptService:WaitForChild("ServerCode")

local Network = require(ReplicatedCode.Framework.Core.Network)
local RemoteEventKey = require(ReplicatedCode.GameLogic.SharedConstants.Keys.RemoteEventKey)
local PurchaseManager = require(ServerCode.GameLogic.Managers.PurchaseManager)
local GamepassService = require(ServerCode.GameLogic.Service.AxeTycoon.GamepassService)

local StoreService = {}

local started = false

function StoreService.start()
	if started then
		return
	end
	started = true

	-- 客户端 BuyButton 点击购买时触发：服务端据此弹出 Robux 付款框。
	Network.connectEvent(RemoteEventKey.PurchasePending, function(player, currencyType, id)
		if type(currencyType) ~= "string" or type(id) ~= "number" then
			return
		end
		PurchaseManager.currencyHandle(player, currencyType, id)
	end)
end

function StoreService.listen()
end

function StoreService.grantGamepass(player: Player, gamepassId: number)
	return GamepassService.grantById(player, gamepassId)
end

return StoreService
