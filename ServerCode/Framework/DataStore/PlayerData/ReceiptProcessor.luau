--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

--[[
ReceiptProcessor 处理开发人员购买产品的过程。请遵循以下原则

	1. 所有购买都有一个数据存储表示
	2. 在将购买保存到数据存储中之前，不应最终确定购买。

	本文件旨在解决 ProcessReceipt 实现中的常见问题，包括

	1. 在玩家的数据存储中记录购买之前返回 PurchaseGranted
	2. 在单独的非原子 GetAsync / SetAsync 调用中检查和记录 PurchaseId
	3. 实施复杂的事务系统，以原子方式更新会话和数据存储数据
	4. 如果初次尝试保存失败，即使后来的尝试成功，也会将购买记录为失败
--]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local PlayerDataServer = require(ServerScriptService.ServerCode.Framework.DataStore.PlayerData.PlayerDataServer)
local waitForFirstAsync = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Instance.WaitForFirstAsync)


local MAX_RECEIPT_HISTORY = 100  -- 玩家数据中存储收据的最大数量
local RECEIPT_HISTORY_VALUE_NAME = "__receiptHistory" -- 玩家数据中存储收据历史记录的值的名称

type ProductCallback = (Player, number) -> nil

type ReceiptInfo = {
	PurchaseId: string, -- 特定购买的唯一标识符
	PlayerId: number, --进行购买的玩家的 ID
	ProductId: number, --购买产品的 ID
	CurrencySpent: number, -- 购买时花费的货币数量
	CurrencyType: Enum.CurrencyType, -- 购买时花费的货币类型；总是枚举货币类型（Enum.CurrencyType）.Robux
	PlaceIdWherePurchased: number, -- 购买产品的地点的 ID（不一定与当前地点的 ID 相同）
}

local ReceiptProcessor = {}
ReceiptProcessor._productCallbacks = {} :: { [number]: ProductCallback }
-- 我们将此常量作为 ReceiptProcessor 的一个属性公开，这样 PlayerData 系统就可以将其设置为一个
-- 不会复制到客户端的私有值
ReceiptProcessor.receiptHistoryValueName = RECEIPT_HISTORY_VALUE_NAME

function ReceiptProcessor.start()
	MarketplaceService.ProcessReceipt = function(receiptInfo: ReceiptInfo)
		local playerId = receiptInfo.PlayerId
		local productId = receiptInfo.ProductId
		local purchaseId = receiptInfo.PurchaseId

		local result = ReceiptProcessor._processReceiptAsync(playerId, productId, purchaseId)

		return result
	end
end

-- 产品回调是操作会话数据以处理购买的函数
-- Example:
-- ReceiptProcessor.registerProductCallback(12345, function(player)
-- 	PlayerDataServer.updateValue(player, "coins", function(oldValue)
-- 		return oldValue + 1
-- 	end)
-- end)
function ReceiptProcessor.registerProductCallback(developerProductId: number, productCallback: ProductCallback)
	--assert(
	--	not ReceiptProcessor._productCallbacks[developerProductId],
	--	string.format("Developer product %d already has a callback assigned", developerProductId)
	--)
	ReceiptProcessor._productCallbacks[developerProductId] = productCallback
end

function ReceiptProcessor._processReceiptAsync(
	playerId: number,
	productId: number,
	purchaseId: string
): Enum.ProductPurchaseDecision
	-- 如果玩家当前不在服务器中，我们不想保存玩家数据
	local player = Players:GetPlayerByUserId(playerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- 因为 ProcessReceipt 可以在玩家加入服务器时调用，所以我们要确保我们已经
	-- 让玩家的数据有时间加载，然后再继续游戏
	if PlayerDataServer.isLoading(player) then
		-- 在这里，我们等待玩家的数据加载或者玩家离开服务器（以先发生者为准）。
		-- 我们在这里把玩家离开服务器也包括在内，就好像当玩家离开服务器时，我们无限期地屈服一样
		--在他们的数据加载之前，ProcessReceipt 将被阻止在此服务器上再次调用，即使玩家重新加入也是如此。
		-- 即使玩家重新加入。
		waitForFirstAsync(function()
			PlayerDataServer.waitForDataLoadAsync(player)
		end, function()
			-- TODO: Replace with player.Destroying:Wait() when that fires on player leave
			local _, playerParent
			repeat
				_, playerParent = player.AncestryChanged:Wait()
			until playerParent == nil
		end)
	end

	-- 如果玩家数据正在加载、出错或保存功能被禁用，我们不想保存玩家数据
	-- 该检查还将捕捉玩家是否在数据未加载的情况下离开
	if not RunService:IsStudio() and not PlayerDataServer.canSave(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- 这里假设在调用 ProcessReceipt 时，PlayerDataServer 已经完成了该玩家的数据加载，
	-- 且整个体验中所有对玩家数据的修改都通过 PlayerDataServer 进行。
	-- 在这种约定下，可以认为当前会话内存中的玩家数据已经包含了最新的状态，
	-- 因此不再需要在此处额外读取 DataStore 中的值进行比对。
	local receiptsProcessed = PlayerDataServer.getValue(player, ReceiptProcessor.receiptHistoryValueName) or {}
	if table.find(receiptsProcessed, purchaseId) then
		-- 我们将传入 syncedValueOnly 参数，因此我们将只获取已
		-- 成功加载或保存到数据存储的值。
		local receiptsProcessedSynced = PlayerDataServer.getValue(
			player,
			ReceiptProcessor.receiptHistoryValueName,
			true
		) or {}

		if not table.find(receiptsProcessedSynced, purchaseId) then
			-- 当前会话数据显示购买已在此会话中处理，但这并没有反映在
			-- 数据存储中反映出来。这表明，PlayerDataServer.saveDataAsync 在之前的 ProcessReceipt 回调中没有保存
			-- 的回调中保存失败。在这种情况下，我们将返回 NotProcessedYet。下一次运行此回调时，如果数据已经
			-- 保存成功，它将返回 PurchaseGranted。

			-- 虽然我们_可以_在这里提示另一次保存，但我们选择不这样做，因为让
			-- 玩家数据保存在随后的玩家数据自动保存/玩家离开时触发的保存中

			warn("PurchaseId found in session ReceiptHistory but not player ReceiptHistory.")
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		-- 由于购买 ID 已存储在会话数据中，并反映在数据存储中，因此我们知道购买已
		-- 已在本次会话或上一次会话中处理过。重要的是，我们要在此返回 PurchaseGranted，以捕捉以下情况
		-- 购买已完成处理，但 ProcessReceipt 未在后台服务中记录的情况。
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	-- 如果没有设置产品回调，我们将无法处理该购买行为
	local productCallback = ReceiptProcessor._productCallbacks[productId]
	if not productCallback then
		warn(string.format("Product %d has no callback set", productId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- 在产品回调内的用户会话数据中处理购买行为
	local productSuccess, productResult = pcall(productCallback, player, productId)

	-- 如果产品回调出错，我们将无法处理购买行为
	if not productSuccess then
		warn("Error when calling product callback: " .. tostring(productResult))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- 我们需要在玩家数据历史记录中存储收据 ID，这样就不会重复奖励该购买行为
	PlayerDataServer.updateValue(player, ReceiptProcessor.receiptHistoryValueName, function(receipts: { string })
		receipts = receipts or {}
		table.insert(receipts, purchaseId)

		if #receipts > MAX_RECEIPT_HISTORY then
			table.remove(receipts, 1) -- 删除列表开头部分
		end

		return receipts
	end)
	
	if not RunService:IsStudio() then
		local saveSuccess, saveResult = PlayerDataServer.saveDataAsync(player)

		-- 只有成功保存到数据存储中，我们才会将此购买记录为已处理
		-- 如果保存失败，我们将把这次购买记录为尚未处理
		if not saveSuccess then
			warn("Failed to save player data while processing receipt: " .. tostring(saveResult))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

	end
	
	-- 我们现在知道购买已在当前会话中得到正确处理，并且更改
	-- 已保存到数据存储中，因此我们可以将此购买标记为最终完成
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

return ReceiptProcessor

