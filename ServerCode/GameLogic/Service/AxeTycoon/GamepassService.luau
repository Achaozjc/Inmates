--!strict

--[[
	通行证服务（服务端权威）。

	职责：
	1. 拥有判定：玩家加入时，对每个通行证先读持久化（PlayerData.Store.gamepass，存通行证 ID），
	   未记录则 UserOwnsGamePassAsync 回查并补登；随后把拥有状态写入玩家属性供客户端读取。
	2. 购买授予：监听 MarketplaceService.PromptGamePassPurchaseFinished，购买成功后落库 + 置属性。
	3. 自动结算：每 AUTO_INTERVAL 秒遍历玩家——
	      AutoCollectCash → CollectMoneyService.collect（PendingCash 自动领取为 Cash）
	      AutoCollectWood → WoodCarryService.pickup + ProcessorService.deposit（自动背木入库）

	双倍木料（DoubleWood）不在此结算：ProcessorService.deposit 直接读取拥有属性 ×2，避免循环 require。
	购买入口经 BuyButton/HUD → PurchasePending(GamePass) → PurchaseManager.promptGamepass 弹窗。
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ReplicatedCode = ReplicatedStorage:WaitForChild("ReplicatedCode")
local ServerCode = ServerScriptService:WaitForChild("ServerCode")

local safePlayerAdded = require(ReplicatedCode.Framework.Utility.Player.SafePlayerAdded)
local setInterval = require(ReplicatedCode.Framework.Utility.Time.SetInterval)
local GamepassConfig = require(ReplicatedCode.GameLogic.Shared.Configs.GamepassConfig)
local StoreIdCategory = require(ReplicatedCode.GameLogic.SharedConstants.Categories.StoreIdCategory)
local PlayerDataKey = require(ReplicatedCode.GameLogic.SharedConstants.Keys.PlayerDataKey)
local PlayerDataServer = require(ServerCode.Framework.DataStore.PlayerData.PlayerDataServer)
local DebouncedPlayerSave = require(ServerCode.GameLogic.Modules.AxeTycoon.DebouncedPlayerSave)
local CollectMoneyService = require(ServerCode.GameLogic.Service.AxeTycoon.CollectMoneyService)
local WoodCarryService = require(ServerCode.GameLogic.Service.AxeTycoon.WoodCarryService)
local ProcessorService = require(ServerCode.GameLogic.Service.AxeTycoon.ProcessorService)

local GamepassService = {}

local started = false

-- 读取持久化的已拥有通行证 ID 列表
local function getOwnedList(player: Player): { number }
	local store = PlayerDataServer.getValue(player, PlayerDataKey.Store)
	local gamepasses = if type(store) == "table" then store.gamepass else nil
	return if type(gamepasses) == "table" then gamepasses else {}
end

-- 通行证 ID 是否已持久化为已拥有
local function ownsId(player: Player, gamepassId: number): boolean
	if gamepassId <= 0 then
		return false
	end
	return table.find(getOwnedList(player), gamepassId) ~= nil
end

-- 把某通行证 ID 落库为已拥有（去重）；返回是否新增
local function persistOwnership(player: Player, gamepassId: number): boolean
	local added = false
	PlayerDataServer.updateValue(player, PlayerDataKey.Store, function(store)
		store = if type(store) == "table" then store else {}
		local gamepasses = if type(store.gamepass) == "table" then store.gamepass else {}
		if table.find(gamepasses, gamepassId) == nil then
			table.insert(gamepasses, gamepassId)
			added = true
		end
		store.gamepass = gamepasses
		return store
	end)
	return added
end

-- 按 key 查询拥有状态（供其他服务读取，如需要时）
function GamepassService.ownsByKey(player: Player, key: string): boolean
	local gamepassId = StoreIdCategory.Gamepass[key]
	return gamepassId ~= nil and ownsId(player, gamepassId)
end

-- 把当前拥有状态写入玩家属性，供客户端 UI 读取
function GamepassService.syncAttributes(player: Player)
	for _, pass in ipairs(GamepassConfig.Passes) do
		local gamepassId = StoreIdCategory.Gamepass[pass.key]
		player:SetAttribute(pass.attribute, gamepassId ~= nil and ownsId(player, gamepassId))
	end
end

-- 授予指定通行证 ID（落库 + 置属性 + 调度落盘）
function GamepassService.grantById(player: Player, gamepassId: number): boolean
	if gamepassId <= 0 then
		return false
	end
	local added = persistOwnership(player, gamepassId)
	GamepassService.syncAttributes(player)
	if added then
		DebouncedPlayerSave.schedule(player)
	end
	return added
end

-- 加入时确认每个通行证的拥有状态：先读库，未记录则回查 MarketplaceService 并补登
local function reconcileOwnership(player: Player)
	for _, pass in ipairs(GamepassConfig.Passes) do
		local gamepassId = StoreIdCategory.Gamepass[pass.key]
		if gamepassId and gamepassId > 0 and not ownsId(player, gamepassId) then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamepassId)
			end)
			if ok and owns then
				persistOwnership(player, gamepassId)
				DebouncedPlayerSave.schedule(player)
			end
		end
	end
	GamepassService.syncAttributes(player)
end

-- 每 AUTO_INTERVAL 秒：对拥有自动类通行证的玩家执行自动收集
local function autoTick()
	local autoCashId = StoreIdCategory.Gamepass.AutoCollectCash
	local autoWoodId = StoreIdCategory.Gamepass.AutoCollectWood

	for _, player in Players:GetPlayers() do
		if not PlayerDataServer.hasLoaded(player) then
			continue
		end

		if autoCashId and autoCashId > 0 and ownsId(player, autoCashId) then
			CollectMoneyService.collect(player)
		end

		if autoWoodId and autoWoodId > 0 and ownsId(player, autoWoodId) then
			-- 静默拾取：自动收集时不在 HUD 弹出拾取飘字
			WoodCarryService.pickup(player, true)
			ProcessorService.deposit(player)
		end
	end
end

function GamepassService.start()
	if started then
		return
	end
	started = true

	-- 购买成功回调：定位对应通行证后授予
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamepassId, wasPurchased)
		if wasPurchased then
			GamepassService.grantById(player, gamepassId)
		end
	end)

	safePlayerAdded(function(player)
		PlayerDataServer.waitForDataLoadAsync(player)
		reconcileOwnership(player)
	end)

	setInterval(autoTick, GamepassConfig.AUTO_INTERVAL)
end

return GamepassService
