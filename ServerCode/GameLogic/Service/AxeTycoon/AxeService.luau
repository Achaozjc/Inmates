--!strict

--[[
	斧子服务（服务端权威）。

	购买斧子：玩家角色触碰自己基地 TouchedButtons 下的 BuyAxe_1/5/25/100 按钮，
	服务端监听 Part.Touched（参考 dingdong 项目 TouchPart 模式：从 otherPart.Parent 取
	Humanoid → Player），做三重校验后执行购买，客户端不发「执行」请求 → 无伪造面：
		1. 触碰者必须是有效存活玩家
		2. 按钮必须属于该玩家自己的基地（part 是其 Base 的后代）
		3. 同一按钮的触碰去抖（BaseConfig.BUTTON_DEBOUNCE）

	购买规则：
	- 买到的均为最低级斧子 Axe_1，由后续「合成」升级；
	- 单价随 ownedAxeCount 动态上涨（见 AxePriceConfig），买 N 把总价 = N × 当前单价；
	- 空槽足够时直接放置，不触发合成；空槽不足（放置必触满槽）时，把现有斧子与
	  整批新斧子一起链式合成后一次性放置（不改变 ownedAxeCount）；连同新斧子整体
	  合成后仍超出槽位上限时，才拒绝整单；
	- 成功后扣 Cash、落库（axes + ownedAxeCount）、刷新按钮上方 Billboard 价格 Label。
	- 购买 AUTO_MERGE_BUNDLE_SIZE（100）把时：纯数据模拟合成后一次性放置最终模型（不逐把生成再销毁）。

	合成：触碰 TouchedButtons/Merge，纯数据链式合成 + 一次性放置；ownedAxeCount 不变。
	基地槽位满（100）时自动尝试合成（与手动 Merge 相同规则，无法合成则跳过）。
	木头生产由 WoodProductionService 每秒 reconcile 自动接管新放置/合成后的斧子，无需此处通知。
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local ReplicatedCode = ReplicatedStorage:WaitForChild("ReplicatedCode")
local ServerCode = ServerScriptService:WaitForChild("ServerCode")

local safePlayerAdded = require(ReplicatedCode.Framework.Utility.Player.SafePlayerAdded)
local ShowUnitNum = require(ReplicatedCode.Framework.UI.ShowUnitNum)
local Network = require(ReplicatedCode.Framework.Core.Network)
local RemoteEventKey = require(ReplicatedCode.GameLogic.SharedConstants.Keys.RemoteEventKey)
local AxeCategory = require(ReplicatedCode.GameLogic.SharedConstants.Categories.AxeCategory)
local AxePriceConfig = require(ReplicatedCode.GameLogic.Shared.Configs.AxePriceConfig)
local BaseConfig = require(ReplicatedCode.GameLogic.Shared.Configs.BaseConfig)
local CashKey = require(ReplicatedCode.GameLogic.SharedConstants.Keys.CashKey)
local PlayerDataKey = require(ReplicatedCode.GameLogic.SharedConstants.Keys.PlayerDataKey)
local PlayerDataServer = require(ServerCode.Framework.DataStore.PlayerData.PlayerDataServer)
local PlayerService = require(ServerCode.GameLogic.Service.Sync.PlayerService)
local Base = require(ServerCode.GameLogic.Modules.AxeTycoon.Base)
local AxeMergeLogic = require(ServerCode.GameLogic.Modules.AxeTycoon.AxeMergeLogic)
local AxeDiscovery = require(ServerCode.GameLogic.Modules.AxeTycoon.AxeDiscovery)
local BaseAssignmentService = require(ServerCode.GameLogic.Service.AxeTycoon.BaseAssignmentService)

-- 购买固定产出最低级斧子，由合成系统逐级升级
local BUY_CATEGORY = AxeCategory.Axe_1
local MERGE_BUTTON_NAME = "Merge"
local MAX_AXE_SLOTS = BaseConfig.FLOOR_COUNT * BaseConfig.SLOTS_PER_FLOOR

local AxeService = {}

-- 按钮名 -> 批量数量，如 "BuyAxe_5" -> 5
local bundleByButtonName: { [string]: number } = {}
for _, bundle in AxePriceConfig.Bundles do
	bundleByButtonName["BuyAxe_" .. bundle] = bundle
end

-- 每个按钮 Part 的上次触发时间（去抖）
local lastTouchAt: { [BasePart]: number } = {}
local started = false

-- 刷新某玩家基地上 4 个 BuyAxe 按钮 Billboard 的价格 Label（按当前 ownedAxeCount 计算）
function AxeService.updateBaseBillboards(player: Player)
	local base = BaseAssignmentService.getBase(player)
	if not base then
		return
	end
	local buttons = base:FindFirstChild("Touch_Merge&Buy")
	if not buttons then
		return
	end

	local axeData = PlayerDataServer.getValue(player, PlayerDataKey.AxeTycoon)
	local ownedAxeCount = if type(axeData) == "table" then (tonumber(axeData.ownedAxeCount) or 0) else 0

	for _, bundle in AxePriceConfig.Bundles do
		local part = buttons:FindFirstChild("BuyAxe_" .. bundle)
		local billboard = part and part:FindFirstChild("Billboard")
		local main = billboard and billboard:FindFirstChild("Main")
		local priceLabel = main and main:FindFirstChild("Price")
		if priceLabel and priceLabel:IsA("TextLabel") then
			priceLabel.Text = "$" .. ShowUnitNum(AxePriceConfig.getBundlePrice(ownedAxeCount, bundle))
		end
	end
end

local function persistAxesFromBase(player: Player, baseObject: Base.ClassType)
	PlayerDataServer.updateValue(player, PlayerDataKey.AxeTycoon, function(data)
		data = if type(data) == "table" then data else {}
		local newAxes: { [string]: string } = {}
		for _, occupied in baseObject:getOccupiedSlots() do
			newAxes[occupied.key] = occupied.category
		end
		data.axes = newAxes
		-- 图鉴：当前占用的稀有度均视为已发现
		AxeDiscovery.recordArray(data, baseObject:getOccupiedCategories())
		return data
	end)
end

-- 购买斧子：放入 bundleSize 把最低级斧子；空槽不足时连同新斧子整体合成后一次性放置。成功返回 true。
function AxeService.buy(player: Player, bundleSize: number): boolean
	local baseObject = BaseAssignmentService.getBaseObject(player)
	if not baseObject then
		return false
	end

	local axeData = PlayerDataServer.getValue(player, PlayerDataKey.AxeTycoon)
	if type(axeData) ~= "table" then
		return false
	end
	local ownedAxeCount = tonumber(axeData.ownedAxeCount) or 0

	local occupiedCategories = baseObject:getOccupiedCategories()
	-- 100 把固定走整体合成；小批量仅在空槽不足（放置必触满槽合成）时，把新斧子全部
	-- 算入合成，与现有斧子一起链式合成后一次性放置
	local isMergedPlacement = bundleSize == AxePriceConfig.AUTO_MERGE_BUNDLE_SIZE
		or MAX_AXE_SLOTS - #occupiedCategories < bundleSize

	-- 容量判定：连同新斧子整体模拟合成，看最终是否在槽位上限内；超出才拒绝整单
	local finalCategories: { string }?
	-- 自动合成途经的稀有度集合（供图鉴记录中间稀有度），直接放置路径为 nil
	local autoMergeProduced: { [string]: boolean }? = nil
	if isMergedPlacement then
		local categories = table.clone(occupiedCategories)
		for _ = 1, bundleSize do
			categories[#categories + 1] = BUY_CATEGORY
		end
		finalCategories, autoMergeProduced = AxeMergeLogic.mergeCategoriesTracked(categories)
		if #(finalCategories :: { string }) > MAX_AXE_SLOTS then
			return false
		end
	end

	-- 容量可行后再扣费（余额不足返回 false，直接放弃，无副作用）
	local price = AxePriceConfig.getBundlePrice(ownedAxeCount, bundleSize)
	if not PlayerService.reduceCash(player, CashKey.Cash, price) then
		return false
	end

	local addedCount = bundleSize

	if isMergedPlacement then
		-- 一次性放置整体合成后的最终模型（不逐把生成再销毁）
		baseObject:applyAxeCategories(finalCategories :: { string })
	else
		-- 空槽足够：直接放置，不触发合成
		local emptySlots = baseObject:getEmptySlotKeys()
		local placed = 0
		for i = 1, bundleSize do
			local key = emptySlots[i]
			local slot = key and baseObject:getSlot(key)
			if slot and slot:placeAxe(BUY_CATEGORY) then
				placed += 1
			end
		end

		baseObject:refreshFloorTransparency()
		addedCount = placed
	end

	-- 全量重建 axes 落库，并按实际新增数累加 ownedAxeCount
	PlayerDataServer.updateValue(player, PlayerDataKey.AxeTycoon, function(data)
		data = if type(data) == "table" then data else {}
		local newAxes: { [string]: string } = {}
		for _, occupied in baseObject:getOccupiedSlots() do
			newAxes[occupied.key] = occupied.category
		end
		data.axes = newAxes
		data.ownedAxeCount = (tonumber(data.ownedAxeCount) or 0) + addedCount
		-- 图鉴：买到的最低级斧、当前占用稀有度、以及自动合成途经的中间稀有度均视为已发现
		AxeDiscovery.recordOne(data, BUY_CATEGORY)
		AxeDiscovery.recordArray(data, baseObject:getOccupiedCategories())
		if autoMergeProduced then
			AxeDiscovery.recordSet(data, autoMergeProduced)
		end
		return data
	end)

	AxeService.tryAutoMergeIfFull(player)
	AxeService.updateBaseBillboards(player)
	return true
end

-- 合成：纯数据链式合成 + 一次性放置；ownedAxeCount 不变。成功返回 true。
function AxeService.merge(player: Player): boolean
	local baseObject = BaseAssignmentService.getBaseObject(player)
	if not baseObject then
		return false
	end

	local categories = baseObject:getOccupiedCategories()
	if #categories == 0 then
		return false
	end

	local counts = AxeMergeLogic.countFromCategories(categories)
	if not AxeMergeLogic.canMerge(counts) then
		return false
	end

	local finalCategories, produced = AxeMergeLogic.mergeCategoriesTracked(categories)
	baseObject:applyAxeCategories(finalCategories)
	-- 图鉴：合成前占用稀有度 + 合成途经产出的中间稀有度均视为已发现
	-- （persistAxesFromBase 仅能记录合成后占用，途经的中间稀有度需在此单独记录）
	PlayerDataServer.updateValue(player, PlayerDataKey.AxeTycoon, function(data)
		data = if type(data) == "table" then data else {}
		AxeDiscovery.recordArray(data, categories)
		AxeDiscovery.recordSet(data, produced)
		return data
	end)
	persistAxesFromBase(player, baseObject)
	return true
end

-- 基地满 100 槽时自动合成（无法合成则跳过）
function AxeService.tryAutoMergeIfFull(player: Player): boolean
	local baseObject = BaseAssignmentService.getBaseObject(player)
	if not baseObject then
		return false
	end
	if baseObject:getOccupiedCount() < MAX_AXE_SLOTS then
		return false
	end
	return AxeService.merge(player)
end

-- 按钮被触碰：识别玩家 + 归属校验 + 去抖 → 购买
local function onButtonTouched(part: BasePart, otherPart: BasePart)
	local character = otherPart.Parent
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end

	-- 归属校验：按钮必须属于该玩家自己的基地
	local base = BaseAssignmentService.getBase(player)
	if not base or not part:IsDescendantOf(base) then
		return
	end

	-- 同一按钮触碰去抖
	local now = os.clock()
	local last = lastTouchAt[part]
	if last and now - last < BaseConfig.BUTTON_DEBOUNCE then
		return
	end
	lastTouchAt[part] = now

	if part.Name == MERGE_BUTTON_NAME then
		-- 仅业务成功才通知客户端在按钮处播放粒子特效
		if AxeService.merge(player) then
			Network.fireClient(RemoteEventKey.TouchButtonVFX, player, part.Name)
		end
		return
	end

	local bundle = bundleByButtonName[part.Name]
	if bundle and AxeService.buy(player, bundle) then
		Network.fireClient(RemoteEventKey.TouchButtonVFX, player, part.Name)
	end
end

-- 绑定单个基地下所有 BuyAxe_* 按钮的 Touched
local function bindBase(base: Folder)
	local buttons = base:FindFirstChild("Touch_Merge&Buy")
	if not buttons then
		return
	end
	for _, bundle in AxePriceConfig.Bundles do
		local part = buttons:FindFirstChild("BuyAxe_" .. bundle)
		if part and part:IsA("BasePart") then
			local capturedPart = part :: BasePart
			capturedPart.Touched:Connect(function(otherPart)
				onButtonTouched(capturedPart, otherPart)
			end)
		end
	end

	local mergePart = buttons:FindFirstChild(MERGE_BUTTON_NAME)
	if mergePart and mergePart:IsA("BasePart") then
		local capturedMerge = mergePart :: BasePart
		capturedMerge.Touched:Connect(function(otherPart)
			onButtonTouched(capturedMerge, otherPart)
		end)
	end
end

function AxeService.start()
	if started then
		return
	end
	started = true

	-- 启动时绑定所有基地的购买按钮（按钮 Part 静态存在，归属在触碰时校验）
	local world = Workspace:FindFirstChild("World")
	if world then
		for _, child in world:GetChildren() do
			if child:IsA("Folder") and string.match(child.Name, "^Base_%d+$") then
				bindBase(child)
			end
		end
	else
		warn("[AxeService] 未找到 Workspace.World，购买按钮未绑定")
	end

	-- 玩家进服且基地分配后，按其数据刷新一次按钮价格
	safePlayerAdded(function(player)
		PlayerDataServer.waitForDataLoadAsync(player)
		local deadline = os.clock() + 10
		while not BaseAssignmentService.getBase(player) and os.clock() < deadline do
			task.wait(0.2)
		end
		AxeService.updateBaseBillboards(player)
	end)
end

return AxeService
