--!strict

-- 开发者商品注册入口。
-- 新项目默认不注册任何商品；接入付费商品时在这里显式注册 ReceiptProcessor 回调。

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProductRegistry = require(ServerScriptService.ServerCode.GameLogic.ProductRegistry)
local ReceiptProcessor = require(ServerScriptService.ServerCode.Framework.DataStore.PlayerData.ReceiptProcessor)
local ProcessorService = require(ServerScriptService.ServerCode.GameLogic.Service.AxeTycoon.ProcessorService)
local CashMultiplierService = require(ServerScriptService.ServerCode.GameLogic.Service.AxeTycoon.CashMultiplierService)
local CashGrantService = require(ServerScriptService.ServerCode.GameLogic.Service.AxeTycoon.CashGrantService)
local ChestService = require(ServerScriptService.ServerCode.GameLogic.Service.AxeTycoon.ChestService)
local StoreIdCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.StoreIdCategory)
local CashMultiplierConfig = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Configs.CashMultiplierConfig)
local CashGrantConfig = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Configs.CashGrantConfig)
local ChestConfig = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Configs.ChestConfig)

local function registerDevProducts()
	-- 立即处理：付费后将处理机全部库存一次性转入 PendingCash，玩家自行 CollectMoney 领取
	local instantProcessId = StoreIdCategory.Product.InstantProcess
	if instantProcessId and instantProcessId > 0 then
		ProductRegistry.register(instantProcessId, { storeCategory = "Processor", itemKey = "InstantProcess" })
		ReceiptProcessor.registerProductCallback(instantProcessId, function(player)
			ProcessorService.instantProcessAll(player)
		end)
	end

	-- Cash 倍率：逐档开发者商品，付费后授予对应倍率档位（仅升级、不降级）
	for tierIndex, tier in ipairs(CashMultiplierConfig.Tiers) do
		local productId = StoreIdCategory.Product[tier.productKey]
		if productId and productId > 0 then
			ProductRegistry.register(productId, { storeCategory = "CashMultiplier", itemKey = tier.productKey })
			ReceiptProcessor.registerProductCallback(productId, function(player)
				CashMultiplierService.grantTier(player, tierIndex)
			end)
		end
	end

	-- 付费金钱：逐档开发者商品，付费后按「档位倍率 × 拥有斧头数」立即发放现金（可重复购买）
	for tierIndex, tier in ipairs(CashGrantConfig.Tiers) do
		local productId = StoreIdCategory.Product[tier.productKey]
		if productId and productId > 0 then
			ProductRegistry.register(productId, { storeCategory = "PayCash", itemKey = tier.productKey })
			ReceiptProcessor.registerProductCallback(productId, function(player)
				CashGrantService.grant(player, tierIndex)
			end)
		end
	end

	-- 宝箱付费开启：六个稀有度各一个开发者商品，付费后开启玩家当前持有的对应宝箱
	for category, chest in ChestConfig.Chests do
		local productKey = chest.productKey
		local productId = if productKey then StoreIdCategory.Product[productKey] else nil
		if productId and productId > 0 then
			ProductRegistry.register(productId, { storeCategory = "Chest", itemKey = productKey })
			ReceiptProcessor.registerProductCallback(productId, function(player)
				ChestService.openChestPaid(player, category)
			end)
		end
	end
end

return registerDevProducts
