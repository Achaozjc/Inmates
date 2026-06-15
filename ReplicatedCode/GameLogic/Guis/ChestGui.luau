--!strict

--[[
	开箱面板（客户端）。

	由「手持宝箱 Tool」驱动显示：本地角色装备带 ChestTool Tag 的 Tool 时弹出，卸下/销毁时关闭。
	展示：宝箱名、顶部稀有度渐变、宝箱模型（ModelViewport 代替 icon）、可开出的斧子及概率、
	开箱花费（CostLabel）、开启按钮（Cash 不足时显示 Robux 付费价）、丢弃按钮。

	按钮 → 服务端 ChestOpen / ChestDiscard；服务端 ChestActionResult 回执驱动 needPaid/baseFull/success。
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = ReplicatedStorage.ReplicatedCode.Framework
local GameLogic = ReplicatedStorage.ReplicatedCode.GameLogic

local GuiBase = require(Framework.UI.GuiBase)
local UILayerId = require(Framework.UI.UILayerId)
local UILayerType = require(Framework.UI.UILayerType)
local ModelViewport = require(Framework.UI.ModelViewport)
local ShowUnitNum = require(Framework.UI.ShowUnitNum)
local DevProductPriceList = require(Framework.Effects.DevProductPriceList)
local PlayerDataClient = require(Framework.DataStore.PlayerDataClient)
local Network = require(Framework.Core.Network)
local ChestConfig = require(GameLogic.Shared.Configs.ChestConfig)
local ColorEnum = require(GameLogic.Shared.Enums.ColorEnum)
local AttributeEnum = require(GameLogic.Shared.Enums.AttributeEnum)
local TagCategory = require(GameLogic.SharedConstants.Categories.TagCategory)
local StoreIdCategory = require(GameLogic.SharedConstants.Categories.StoreIdCategory)
local RichTextCategory = require(GameLogic.SharedConstants.Categories.RichTextCategory)
local CashKey = require(GameLogic.SharedConstants.Keys.CashKey)
local PlayerDataKey = require(GameLogic.SharedConstants.Keys.PlayerDataKey)
local RemoteEventKey = require(GameLogic.SharedConstants.Keys.RemoteEventKey)

local localPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() :: Player

-- HUD 级：与主 HUD 共存、不参与菜单栈；面板显隐由内部 Frame.Visible 控制（手持宝箱时显示）
local ChestGui = GuiBase.new(UILayerId.GUI_Chest, UILayerType.HeadsUpDisplay)

-- 缓存节点
local panelFrame: Frame? = nil
local titleLabel: TextLabel? = nil
local topGradient: UIGradient? = nil
local iconHolder: Frame? = nil
local rowsHolder: Frame? = nil
local rowTemplate: Frame? = nil
local costLabel: TextLabel? = nil
local openButton: TextButton? = nil
local discardButton: TextButton? = nil

local currentCategory: string? = nil
local currentPrice = 0
local isRobuxMode = false
local isOpening = false
local viewport: ModelViewport.ClassType? = nil

-- 读取客户端当前 Cash
local function getCash(): number
	local currency = PlayerDataClient.get(PlayerDataKey.Currency)
	if type(currency) ~= "table" then
		return 0
	end
	return tonumber(currency[CashKey.Cash]) or 0
end

-- 读取客户端累计拥有斧头数（用于开箱单价）
local function getOwnedAxeCount(): number
	local axeTycoon = PlayerDataClient.get(PlayerDataKey.AxeTycoon)
	if type(axeTycoon) ~= "table" then
		return 0
	end
	return tonumber(axeTycoon.ownedAxeCount) or 0
end

-- 解析宝箱模型预制体
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

-- 根据宝箱 category 取稀有度
local function getChestRarity(category: string): number
	local chest = ChestConfig.Chests[category]
	return if chest then chest.rarity else 1
end

-- 从开发者商品 ID 读取 Robux 实价（与 BuyButton 一致）；读不到时回退 ChestConfig.openRobux
local function getOpenRobuxPrice(category: string): number
	local productKey = ChestConfig.getOpenProductKey(category)
	local productId = if productKey then StoreIdCategory.Product[productKey] else nil
	if productId and productId > 0 then
		local cachedPrice = DevProductPriceList.get(productId)
		if cachedPrice and cachedPrice > 0 then
			return cachedPrice
		end
		local ok, productInfo = pcall(function()
			return MarketplaceService:GetProductInfoAsync(productId, Enum.InfoType.Product)
		end)
		if ok and productInfo and productInfo.PriceInRobux then
			return productInfo.PriceInRobux
		end
	end
	return ChestConfig.getOpenRobux(category)
end

-- 顶部 UIGradient 按宝箱稀有度着色
local function applyTopGradient(category: string)
	local gradient = topGradient
	if not gradient then
		return
	end
	local colorSequence = ColorEnum.Chest[getChestRarity(category)]
	if colorSequence then
		gradient.Color = colorSequence
	end
end

-- 刷新 CostLabel 开箱花费
local function applyCostLabel()
	local label = costLabel
	if not label then
		return
	end
	label.Text = "Cost: $" .. ShowUnitNum(currentPrice)
end

-- 切换 Open 按钮文案：Cash 充足显示 Open!，不足显示 Robux 付费价
local function applyButtonMode()
	local button = openButton
	if not button then
		return
	end
	-- 文本写在 Button 子级的 Title 上，而非 Button 本身
	local buttonTitle = button:FindFirstChild("Title")
	if not buttonTitle or not buttonTitle:IsA("TextLabel") then
		return
	end
	if isRobuxMode then
		local robuxPrice = if currentCategory then getOpenRobuxPrice(currentCategory) else ChestConfig.OPEN_ROBUX
		buttonTitle.Text = string.format(RichTextCategory.connnect, ShowUnitNum(robuxPrice), RichTextCategory.robuxSymbol)
	else
		buttonTitle.Text = "Open!"
	end
end

-- Cash / 拥有斧数变化时刷新花费与按钮付费模式
local function refreshAffordability()
	if not currentCategory then
		return
	end
	currentPrice = ChestConfig.getUnlockCost(currentCategory, getOwnedAxeCount())
	isRobuxMode = getCash() < currentPrice
	applyCostLabel()
	applyButtonMode()
end

-- 重建斧子概率行
local function rebuildRows(category: string)
	local holder = rowsHolder
	local template = rowTemplate
	if not holder or not template then
		return
	end

	-- 清掉上次生成的行（保留模板）
	for _, child in holder:GetChildren() do
		if child:IsA("Frame") and child ~= template and child.Name == "Row" then
			child:Destroy()
		end
	end

	for index, prob in ChestConfig.getAxeProbabilities(category) do
		local row = template:Clone()
		row.Name = "Row"
		row.Visible = true
		row.LayoutOrder = index

		local nameLabel = row:FindFirstChild("NameLabel")
		if nameLabel and nameLabel:IsA("TextLabel") then
			nameLabel.Text = prob.name
			local gradient = nameLabel:FindFirstChildOfClass("UIGradient")
			local colorSequence = ColorEnum.Axe[prob.rarity]
			if gradient and colorSequence then
				gradient.Color = colorSequence
			end
		end
		local tierLabel = row:FindFirstChild("TierLabel")
		if tierLabel and tierLabel:IsA("TextLabel") then
			tierLabel.Text = "Tier " .. tostring(prob.rarity)
		end
		local percentLabel = row:FindFirstChild("PercentLabel")
		if percentLabel and percentLabel:IsA("TextLabel") then
			percentLabel.Text = tostring(prob.percent) .. "%"
		end

		row.Parent = holder
	end
end

-- 用某宝箱 category 填充面板
local function populate(category: string)
	currentCategory = category

	if titleLabel then
		titleLabel.Text = ChestConfig.getChestName(category)
	end
	applyTopGradient(category)

	-- 模型 icon
	if viewport then
		viewport:destroy()
		viewport = nil
	end
	local prefab = resolveChestPrefab(category)
	if prefab and iconHolder then
		local vp = ModelViewport.new({
			model = prefab,
			fitVisibleParts = true,
			size = UDim2.fromScale(1, 1),
		})
		vp:setParent(iconHolder)
		viewport = vp
	end

	rebuildRows(category)

	refreshAffordability()
end

-- 当前角色是否装备着宝箱 Tool（返回其 category）
local function getEquippedChestCategory(): string?
	local character = localPlayer.Character
	if not character then
		return nil
	end
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and child:HasTag(TagCategory.ChestTool) then
			local category = child:GetAttribute(AttributeEnum.Category)
			return if type(category) == "string" then category else nil
		end
	end
	return nil
end

local function openPanel(category: string)
	populate(category)
	if panelFrame then
		panelFrame.Visible = true
	end
end

local function closePanel()
	isOpening = false
	currentCategory = nil
	if viewport then
		viewport:destroy()
		viewport = nil
	end
	if panelFrame then
		panelFrame.Visible = false
	end
end

-- 开箱成功：隐藏面板但保留状态，避免 Tool 销毁触发的 closePanel 打断揭晓
local function hidePanelForReveal()
	isOpening = false
	if panelFrame then
		panelFrame.Visible = false
	end
	if viewport then
		viewport:destroy()
		viewport = nil
	end
	currentCategory = nil
end

-- 监听某个角色：装备/卸下宝箱 Tool 时开关面板
local function watchCharacter(character: Model)
	-- 进入时若已手持宝箱，直接打开
	local equipped = getEquippedChestCategory()
	if equipped then
		openPanel(equipped)
	end

	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child:HasTag(TagCategory.ChestTool) then
			local category = child:GetAttribute(AttributeEnum.Category)
			if type(category) == "string" then
				openPanel(category)
			end
		end
	end)
	character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") and child:HasTag(TagCategory.ChestTool) then
			if isOpening then
				return
			end
			if not getEquippedChestCategory() then
				closePanel()
			end
		end
	end)
end

function ChestGui:start()
	local gui = self:bindScreenGui()

	local frame = gui:WaitForChild("Frame") :: Frame
	panelFrame = frame
	-- 默认隐藏，仅手持宝箱时显示
	frame.Visible = false
	local top = frame:WaitForChild("Top") :: Frame
	titleLabel = top:WaitForChild("Title") :: TextLabel
	topGradient = top:WaitForChild("UIGradient") :: UIGradient
	iconHolder = frame:WaitForChild("Icon") :: Frame
	rowsHolder = frame:WaitForChild("Rows") :: Frame
	rowTemplate = rowsHolder:WaitForChild("RowTemplate") :: Frame
	rowTemplate.Visible = false
	costLabel = frame:WaitForChild("CostLabel") :: TextLabel
	openButton = frame:WaitForChild("OpenButton") :: TextButton
	discardButton = frame:WaitForChild("DiscardButton") :: TextButton

	openButton.Activated:Connect(function()
		if not currentCategory then
			return
		end
		isOpening = true
		Network.fireServer(RemoteEventKey.ChestOpen, isRobuxMode)
	end)

	discardButton.Activated:Connect(function()
		if not currentCategory then
			return
		end
		Network.fireServer(RemoteEventKey.ChestDiscard)
		closePanel()
	end)
end

function ChestGui:listen()
	-- 角色装备宝箱 Tool 驱动面板
	if localPlayer.Character then
		watchCharacter(localPlayer.Character)
	end
	localPlayer.CharacterAdded:Connect(function(character)
		closePanel()
		watchCharacter(character)
	end)

	-- Cash / 斧数变化时实时刷新按钮价格
	PlayerDataClient.getUpdateSignal(PlayerDataKey.Currency):Connect(function()
		refreshAffordability()
	end)
	PlayerDataClient.getUpdateSignal(PlayerDataKey.AxeTycoon):Connect(function()
		refreshAffordability()
	end)

	-- 服务端回执
	Network.connectEvent(RemoteEventKey.ChestActionResult, function(payload)
		if type(payload) ~= "table" then
			return
		end
		local status = payload.status
		if status == "needPaid" then
			isOpening = false
			isRobuxMode = true
			applyButtonMode()
		elseif status == "baseFull" then
			isOpening = false
			warn("[ChestGui] Base is full, cannot open chest.")
		elseif status == "success" then
			hidePanelForReveal()
		end
	end, Network.t.table)
end

return ChestGui
