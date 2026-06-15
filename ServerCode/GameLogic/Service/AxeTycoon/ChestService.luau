--!strict

--[[
	宝箱交互服务（服务端权威）。

	负责「捡起 / 开启 / 丢弃」手持宝箱：
	- 捡起：客户端触碰地面宝箱 → 请求 ChestPickup(id)。服务端从 ChestState 移除该宝箱（释放槽位、
	  广播 chestExpire 销毁所有客户端地面模型），写入持久化 heldChest，并生成宝箱 Tool 让玩家手持。
	  同时仅可持有一个：已持有时拒绝再捡。
	- 开启：ChestOpen(paid)。两条分支均先校验基地有空槽（满则回执 baseFull）。
	  Cash 分支再扣费，成功后抽斧并触发客户端揭晓动画；客户端 ChestRevealDone 后再 placeAxe
	  落位基地；Cash 不足回执 needPaid。
	  paid（Robux）分支按持有宝箱稀有度弹出对应开发者商品付款框（商品 ID 服务端推导），
	  付款成功后由收据回调 openChestPaid 免 Cash 开启同一宝箱（复用揭晓流程）。
	- 丢弃：ChestDiscard。清空 heldChest 并销毁 Tool，直接失去宝箱。

	重连：玩家数据加载后若 heldChest 有值，则在背包重建宝箱 Tool（不自动手持）。

	宝箱模型只存在于客户端/Tool，服务端权威数据为 ChestState（地面）与 heldChest（手持）。
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ReplicatedCode = ReplicatedStorage:WaitForChild("ReplicatedCode")
local ServerCode = ServerScriptService:WaitForChild("ServerCode")

local Network = require(ReplicatedCode.Framework.Core.Network)
local safePlayerAdded = require(ReplicatedCode.Framework.Utility.Player.SafePlayerAdded)
local ChestConfig = require(ReplicatedCode.GameLogic.Shared.Configs.ChestConfig)
local AttributeEnum = require(ReplicatedCode.GameLogic.Shared.Enums.AttributeEnum)
local TagCategory = require(ReplicatedCode.GameLogic.SharedConstants.Categories.TagCategory)
local RemoteEventKey = require(ReplicatedCode.GameLogic.SharedConstants.Keys.RemoteEventKey)
local PlayerDataKey = require(ReplicatedCode.GameLogic.SharedConstants.Keys.PlayerDataKey)
local CashKey = require(ReplicatedCode.GameLogic.SharedConstants.Keys.CashKey)
local StoreIdCategory = require(ReplicatedCode.GameLogic.SharedConstants.Categories.StoreIdCategory)
local PlayerDataServer = require(ServerCode.Framework.DataStore.PlayerData.PlayerDataServer)
local PurchaseManager = require(ServerCode.GameLogic.Managers.PurchaseManager)
local PlayerService = require(ServerCode.GameLogic.Service.Sync.PlayerService)
local BaseAssignmentService = require(ServerCode.GameLogic.Service.AxeTycoon.BaseAssignmentService)
local AxeService = require(ServerCode.GameLogic.Service.AxeTycoon.AxeService)
local AxeDiscovery = require(ServerCode.GameLogic.Modules.AxeTycoon.AxeDiscovery)
local ChestState = require(ServerCode.GameLogic.Modules.AxeTycoon.ChestState)

type PendingReveal = {
	axeCategory: string,
	slotKey: string,
}

local ChestService = {}
local started = false
local pendingReveal: { [Player]: PendingReveal } = {}

-- 解析宝箱 Tool 预制体（ReplicatedStorage.Instances.Prefabs.ChestTool）
local function resolveToolPrefab(): Tool?
	local instances = ReplicatedStorage:FindFirstChild("Instances")
	local prefabs = instances and instances:FindFirstChild("Prefabs")
	local tool = prefabs and prefabs:FindFirstChild("ChestTool")
	if tool and tool:IsA("Tool") then
		return tool
	end
	return nil
end

-- 解析宝箱模型预制体（ReplicatedStorage.Instances.Prefabs.Chest.<category>）
local function resolveChestPrefab(category: string): Model?
	local instances = ReplicatedStorage:FindFirstChild("Instances")
	local prefabs = instances and instances:FindFirstChild("Prefabs")
	local chestFolder = prefabs and prefabs:FindFirstChild("Chest")
	local prefab = chestFolder and chestFolder:FindFirstChild(category)
	if prefab and prefab:IsA("Model") then
		return prefab
	end
	return nil
end

-- 读取玩家持有的宝箱 category（未持有返回 nil）
local function getHeldChest(player: Player): string?
	local data = PlayerDataServer.getValue(player, PlayerDataKey.AxeTycoon)
	if type(data) ~= "table" then
		return nil
	end
	local held = data.heldChest
	return if type(held) == "string" then held else nil
end

local function setHeldChest(player: Player, category: string | false)
	PlayerDataServer.updateValue(player, PlayerDataKey.AxeTycoon, function(data)
		data = if type(data) == "table" then data else {}
		data.heldChest = category
		return data
	end)
end

-- 销毁玩家身上/背包内所有宝箱 Tool（保证同时仅一个）
local function destroyChestTools(player: Player)
	local function scan(container: Instance?)
		if not container then
			return
		end
		for _, child in container:GetChildren() do
			if child:IsA("Tool") and child:HasTag(TagCategory.ChestTool) then
				child:Destroy()
			end
		end
	end
	scan(player:FindFirstChild("Backpack"))
	scan(player.Character)
end

-- 构建一个宝箱 Tool（宝箱模型 weld 到 Handle）
local function buildChestTool(category: string): Tool?
	local toolPrefab = resolveToolPrefab()
	local chestPrefab = resolveChestPrefab(category)
	if not toolPrefab or not chestPrefab then
		warn(string.format("[ChestService] 缺少宝箱 Tool/模型预制体（category=%s）", tostring(category)))
		return nil
	end

	local tool = toolPrefab:Clone()
	local handle = tool:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		tool:Destroy()
		return nil
	end

	local model = chestPrefab:Clone()
	local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if not primary then
		tool:Destroy()
		model:Destroy()
		return nil
	end

	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.Massless = true
		end
	end

	-- Handle 相对宝箱沿宝箱 Z 轴正方向偏移 z/2（即宝箱模型沿 Handle -Z 方向偏移半个深度）
	local chestDepth = model:GetExtentsSize().Z
	model:PivotTo(handle.CFrame * CFrame.new(0, 0, -chestDepth / 2))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = primary
	weld.Parent = handle
	model.Parent = tool

	tool.Name = ChestConfig.getChestName(category)
	tool.ToolTip = tool.Name
	tool:SetAttribute(AttributeEnum.Category, category)
	tool:AddTag(TagCategory.ChestTool)
	return tool
end

-- 合成规则：3 合 1，故 n 级斧子 = 3^(n-1) 个 1 级斧子（与 AxeMergeLogic 一致）
local MERGE_INPUT_COUNT = 3

-- n 级斧子折算成 1 级当量（用于累加 ownedAxeCount，保持与"合成不变"口径一致）
local function getAxeEquivalent(axeCategory: string): number
	local level = tonumber(axeCategory)
	if not level or level < 1 then
		return 0
	end
	return MERGE_INPUT_COUNT ^ (level - 1)
end

-- 把基地当前占用斧子持久化到 axes（与 AxeService 一致）；
-- addedAxeEquivalent 为本次新增斧子的 1 级当量，累加到 ownedAxeCount（只增不减）
local function persistAxesFromBase(player: Player, baseObject: any, addedAxeEquivalent: number?)
	PlayerDataServer.updateValue(player, PlayerDataKey.AxeTycoon, function(data)
		data = if type(data) == "table" then data else {}
		local newAxes: { [string]: string } = {}
		for _, occupied in baseObject:getOccupiedSlots() do
			newAxes[occupied.key] = occupied.category
		end
		data.axes = newAxes
		if addedAxeEquivalent and addedAxeEquivalent > 0 then
			data.ownedAxeCount = (tonumber(data.ownedAxeCount) or 0) + addedAxeEquivalent
		end
		-- 图鉴：当前占用的稀有度均视为已发现
		AxeDiscovery.recordArray(data, baseObject:getOccupiedCategories())
		return data
	end)
end

local function fireResult(player: Player, status: string, axeCategory: string?, chestCategory: string?)
	Network.fireClient(RemoteEventKey.ChestActionResult, player, {
		status = status,
		axe = axeCategory,
		chestCategory = chestCategory,
	})
end

-- 将 pending 中的斧头落位到基地（揭晓完成或玩家离开时调用）
local function commitPendingReveal(player: Player): boolean
	local pending = pendingReveal[player]
	if not pending then
		return false
	end
	pendingReveal[player] = nil

	local baseObject = BaseAssignmentService.getBaseObject(player)
	if not baseObject then
		return false
	end

	local slot = baseObject:getSlot(pending.slotKey)
	if slot and slot:placeAxe(pending.axeCategory) then
		baseObject:relayoutAxesByRarityDesc()
		persistAxesFromBase(player, baseObject, getAxeEquivalent(pending.axeCategory))
		AxeService.tryAutoMergeIfFull(player)
		-- ownedAxeCount 已增加，刷新买斧按钮 Billboard 价格
		AxeService.updateBaseBillboards(player)
		return true
	end
	return false
end

-- 捡起地面宝箱 → 手持
local function onPickup(player: Player, id: number)
	if type(id) ~= "number" then
		return
	end
	-- 同时仅一个：已持有则拒绝
	if getHeldChest(player) then
		return
	end

	-- 仅本人 ChestState 内的宝箱可被移除（天然鉴权）
	local removed = ChestState.removeChest(player.UserId, id)
	if not removed then
		return
	end

	-- 销毁所有客户端的地面模型
	Network.fireAllClients(RemoteEventKey.AxeTycoonSync, {
		kind = "chestExpire",
		id = id,
	})

	setHeldChest(player, removed.category)

	destroyChestTools(player)
	local tool = buildChestTool(removed.category)
	if tool then
		-- 父级设为角色即自动装备（手持）
		tool.Parent = player.Character or player:FindFirstChild("Backpack")
	end
end

-- 核心开箱：抽斧、消耗宝箱、触发客户端揭晓动画并登记落位槽。
-- 调用前必须已确认基地有空槽（slotKey 为空槽 key）。Cash 与 Robux 两条路径共用。
local function revealChest(player: Player, category: string, slotKey: string)
	local axeCategory = ChestConfig.rollAxe(category)
	setHeldChest(player, false)
	destroyChestTools(player)

	if not axeCategory then
		fireResult(player, "success", nil, category)
		return
	end

	-- 图鉴：开箱抽到的斧头稀有度视为已发现（落位前即记录，避免揭晓中途离开丢失）
	PlayerDataServer.updateValue(player, PlayerDataKey.AxeTycoon, function(data)
		data = if type(data) == "table" then data else {}
		AxeDiscovery.recordOne(data, axeCategory)
		return data
	end)

	pendingReveal[player] = {
		axeCategory = axeCategory,
		slotKey = slotKey,
	}

	Network.fireClient(RemoteEventKey.Chest_OpenAnim, player, category, axeCategory)
	fireResult(player, "success", axeCategory, category)
end

-- 弹出该宝箱稀有度对应的 Robux 开发者商品付款框（商品 ID 由服务端按持有宝箱推导，杜绝伪造）。
-- 实际开箱在收据回调 ChestService.openChestPaid 中完成。
local function promptPaidOpen(player: Player, category: string)
	local productKey = ChestConfig.getOpenProductKey(category)
	local productId = if productKey then StoreIdCategory.Product[productKey] else nil
	if not productId or productId <= 0 then
		warn(string.format("[ChestService] 宝箱付费开启商品未配置（category=%s）", tostring(category)))
		return
	end
	PurchaseManager.promptProduct(player, productId)
end

-- 开启宝箱（paid=true 走 Robux 付费，paid=false/nil 走 Cash）
local function onOpen(player: Player, paid: boolean)
	local category = getHeldChest(player)
	if not category then
		return
	end

	local baseObject = BaseAssignmentService.getBaseObject(player)
	if not baseObject then
		return
	end

	-- 先校验空槽，避免扣费/付款后放不下（Robux 分支也在弹付款框前拦截）
	local emptySlots = baseObject:getEmptySlotKeys()
	if #emptySlots == 0 then
		fireResult(player, "baseFull")
		return
	end

	-- Robux 付费开启：弹出对应稀有度商品付款框，开箱在收据回调中完成
	if paid == true then
		promptPaidOpen(player, category)
		return
	end

	local axeData = PlayerDataServer.getValue(player, PlayerDataKey.AxeTycoon)
	local ownedAxeCount = if type(axeData) == "table" then (tonumber(axeData.ownedAxeCount) or 0) else 0
	local price = ChestConfig.getUnlockCost(category, ownedAxeCount)

	-- 扣费失败（余额不足）→ 提示客户端切换付费开启
	if not PlayerService.reduceCash(player, CashKey.Cash, price) then
		fireResult(player, "needPaid")
		return
	end

	revealChest(player, category, emptySlots[1])
end

-- 收据回调：Robux 付费成功后开启玩家当前持有的宝箱（不扣 Cash）。
-- expectedCategory 为所购商品对应的宝箱稀有度，仅用于校验与日志。
function ChestService.openChestPaid(player: Player, expectedCategory: string?)
	local category = getHeldChest(player)
	if not category then
		-- 付款过程中宝箱已被开启或丢弃，无可开启目标
		return
	end
	if expectedCategory and category ~= expectedCategory then
		warn(string.format(
			"[ChestService] 付费开箱稀有度不匹配（held=%s expected=%s），按持有宝箱开启",
			tostring(category),
			tostring(expectedCategory)
		))
	end

	local baseObject = BaseAssignmentService.getBaseObject(player)
	if not baseObject then
		return
	end

	local emptySlots = baseObject:getEmptySlotKeys()
	if #emptySlots == 0 then
		fireResult(player, "baseFull")
		return
	end

	revealChest(player, category, emptySlots[1])
end

-- 客户端揭晓结束 → 落位斧头
local function onRevealDone(player: Player)
	commitPendingReveal(player)
end

-- 丢弃宝箱（直接失去）
local function onDiscard(player: Player)
	if not getHeldChest(player) then
		return
	end
	setHeldChest(player, false)
	destroyChestTools(player)
end

-- 重连：若持有宝箱则重建 Tool 并自动手持（原生背包已关闭，玩家无法手动装备）
local function onPlayerAdded(player: Player)
	PlayerDataServer.waitForDataLoadAsync(player)
	local category = getHeldChest(player)
	if not category then
		return
	end
	destroyChestTools(player)
	local tool = buildChestTool(category)
	if not tool then
		return
	end
	-- 等角色与 Humanoid 就绪，parent 到角色即自动装备（手持），从而触发客户端开箱面板
	local character = player.Character or player.CharacterAdded:Wait()
	character:WaitForChild("Humanoid")
	tool.Parent = character
end

function ChestService.start()
	if started then
		return
	end
	started = true

	Network.connectEvent(RemoteEventKey.ChestPickup, onPickup, Network.t.number)
	Network.connectEvent(RemoteEventKey.ChestOpen, onOpen, Network.t.boolean)
	Network.connectEvent(RemoteEventKey.ChestDiscard, onDiscard)
	Network.connectEvent(RemoteEventKey.ChestRevealDone, onRevealDone)

	Players.PlayerRemoving:Connect(function(player)
		commitPendingReveal(player)
	end)

	safePlayerAdded(onPlayerAdded)
end

return ChestService
