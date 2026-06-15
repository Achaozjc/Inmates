--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProductRegistry = require(ServerScriptService.ServerCode.GameLogic.ProductRegistry)
local CurrencyTypes = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Types.CurrencyTypes)

local PurchaseManager = {}

function PurchaseManager.promptProduct(player: Player, productId: number): (boolean, string?)
	if productId <= 0 then
		return false, "Product id must be positive."
	end

	if not ProductRegistry.has(productId) then
		warn(string.format("[PurchaseManager] productId %d is not registered.", productId))
		return false, "Product is not registered."
	end

	MarketplaceService:PromptProductPurchase(player, productId)
	return true, nil
end

function PurchaseManager.promptPurchase(player: Player, productId: number): (boolean, string?)
	return PurchaseManager.promptProduct(player, productId)
end

function PurchaseManager.promptGamepass(player: Player, gamepassId: number): (boolean, string?)
	if gamepassId <= 0 then
		return false, "Gamepass id must be positive."
	end

	MarketplaceService:PromptGamePassPurchase(player, gamepassId)
	return true, nil
end

function PurchaseManager.currencyHandle(player: Player, currencyType: string, id: number): (boolean, string?)
	if currencyType == CurrencyTypes.PriceType.Product then
		return PurchaseManager.promptProduct(player, id)
	elseif currencyType == CurrencyTypes.PriceType.GamePass then
		return PurchaseManager.promptGamepass(player, id)
	end

	return false, "Unsupported purchase currency."
end

return PurchaseManager
