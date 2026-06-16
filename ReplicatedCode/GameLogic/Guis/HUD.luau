--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local Framework = ReplicatedStorage.ReplicatedCode.Framework
local GameLogic = ReplicatedStorage.ReplicatedCode.GameLogic

local GuiBase = require(Framework.UI.GuiBase)
local UILayerId = require(Framework.UI.UILayerId)
local UILayerType = require(Framework.UI.UILayerType)
local UILayerHandler = require(Framework.UI.UILayerHandler)
local NetSignals = require(Framework.Core.Network.NetSignals)
local ShowUnitNum = require(Framework.UI.ShowUnitNum)
local DevProductPriceList = require(Framework.Effects.DevProductPriceList)
local PlayerDataClient = require(Framework.DataStore.PlayerDataClient)
local Network = require(Framework.Core.Network)
local WoodConfig = require(GameLogic.Shared.Configs.WoodConfig)
local WoodPickupPopup = require(GameLogic.Modules.WoodPickupPopup)
local BaseConfig = require(GameLogic.Shared.Configs.BaseConfig)
local CashMultiplierConfig = require(GameLogic.Shared.Configs.CashMultiplierConfig)
local CashGrantConfig = require(GameLogic.Shared.Configs.CashGrantConfig)
local AttributeEnum = require(GameLogic.Shared.Enums.AttributeEnum)
local CashKey = require(GameLogic.SharedConstants.Keys.CashKey)
local PlayerDataKey = require(GameLogic.SharedConstants.Keys.PlayerDataKey)
local RemoteEventKey = require(GameLogic.SharedConstants.Keys.RemoteEventKey)
local CurrencyTypes = require(GameLogic.SharedConstants.Types.CurrencyTypes)
local StoreIdCategory = require(GameLogic.SharedConstants.Categories.StoreIdCategory)
local RichTextCategory = require(GameLogic.SharedConstants.Categories.RichTextCategory)
local TriggerSignalCategory = require(GameLogic.SharedConstants.Categories.TriggerSignalCategory)
local AxeCategory = require(GameLogic.SharedConstants.Categories.AxeCategory)

local localPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() :: Player

local HUD = GuiBase.new(UILayerId.HUD, UILayerType.HeadsUpDisplay)

local cashLabel: TextLabel? = nil
local pendingCashLabel: TextLabel? = nil
local woodAmountLabel: TextLabel? = nil
local totalAxeLabel: TextLabel? = nil
local indexAmountLabel: TextLabel? = nil

-- 图鉴斧子总数（稀有度种类数，固定 24）
local AXE_TOTAL = 0
for _ in AxeCategory do
	AXE_TOTAL += 1
end

local cashMultiplierFrame: Frame? = nil
local cashMultiplierButton: GuiButton? = nil
local cashMultiplierTitle: TextLabel? = nil
local cashMultiplierPrice: TextLabel? = nil
local cashMultiplierLabel: TextLabel? = nil
local lastCashMultiplierClickAt = 0

-- 付费金钱（PayCash）面板：每档一行，展示「+发放现金」并点击付费
type PayCashTier = {
	amountLabel: TextLabel,
	productId: number,
}
local payCashTiers: { PayCashTier } = {}
local lastPayCashClickAt = 0
local lastHomeClickAt = 0

-- 切换 Menu 层显示（TopButtons 的 Codes / Config 等入口）
local function toggleMenuLayer(layerId: UILayerId.EnumType)
	if not UILayerHandler._layerDataById[layerId] then
		warn(string.format("[HUD] 层 %q 未注册，请检查对应 GUI 是否初始化成功", layerId))
		return
	end
	if UILayerHandler.isVisible(layerId) then
		UILayerHandler.hide(layerId)
	else
		UILayerHandler.show(layerId)
	end
end

-- MidTop.Home：回家按钮，点击请求服务端把玩家传送回自己基地
local function bindHomeButton(gui: ScreenGui)
	local midTop = gui:FindFirstChild("MidTop") :: Frame?
	local home = midTop and midTop:FindFirstChild("Home") :: Frame?
	local homeButton = home and home:FindFirstChild("Button") :: GuiButton?
	if not homeButton then
		warn("[HUD] 未找到 Home 按钮（MidTop.Home.Button），请检查 HUD 预制体")
		return
	end

	homeButton.Activated:Connect(function()
		local now = os.clock()
		if now - lastHomeClickAt < BaseConfig.BUTTON_DEBOUNCE then
			return
		end
		lastHomeClickAt = now

		Network.fireServer(RemoteEventKey.HomeTeleport)
	end)
end

-- Right.TopButtons：Codes / Config 入口（移植自 spicy GUI_HUD）
local function bindTopButtons(gui: ScreenGui)
	local right = gui:FindFirstChild("Right") :: Frame?
	local topButtons = right and right:FindFirstChild("TopButtons") :: Frame?
	if not topButtons then
		warn("[HUD] 未找到 Right.TopButtons，请检查 HUD 预制体")
		return
	end

	local configBtn = topButtons:FindFirstChild("Config")
	if configBtn and configBtn:IsA("GuiButton") then
		configBtn.Activated:Connect(function()
			toggleMenuLayer(UILayerId.GUI_Setting)
		end)
	else
		warn("[HUD] 未找到 Config 入口按钮（Right.TopButtons.Config）")
	end

	local codesInst: Instance? =
		topButtons:FindFirstChild("Codes")
		or topButtons:FindFirstChild("Code")
		or topButtons:FindFirstChild("CodesButton")
		or topButtons:FindFirstChild("CodeButton")

	if codesInst and codesInst:IsA("GuiButton") then
		codesInst.Activated:Connect(function()
			toggleMenuLayer(UILayerId.GUI_Codes)
		end)
	else
		warn("[HUD] 未找到 Codes 入口按钮（Right.TopButtons.Codes 等）")
	end
end

local function getCashAmount(currency: any): number
	if type(currency) ~= "table" then
		return 0
	end
	return tonumber(currency[CashKey.Cash]) or 0
end

local function getPendingCashAmount(currency: any): number
	if type(currency) ~= "table" then
		return 0
	end
	return tonumber(currency[CashKey.PendingCash]) or 0
end

local function refreshCashLabel()
	local label = cashLabel
	if not label then
		return
	end

	local currency = PlayerDataClient.get(PlayerDataKey.Currency)
	label.Text = string.format(RichTextCategory.cash, ShowUnitNum(getCashAmount(currency)))
end

local function refreshPendingCashLabel()
	local label = pendingCashLabel
	if not label then
		return
	end

	local currency = PlayerDataClient.get(PlayerDataKey.Currency)
	label.Text = string.format("Pending: %s", string.format(RichTextCategory.cash, ShowUnitNum(getPendingCashAmount(currency))))
end

local function getCarryingWoodValueFromAxeTycoon(axeTycoon: any): number
	if type(axeTycoon) ~= "table" then
		return 0
	end
	return WoodConfig.sumCarryingValue(axeTycoon.carrying)
end

local function refreshWoodAmountLabel()
	local label = woodAmountLabel
	if not label then
		return
	end

	local axeTycoon = PlayerDataClient.get(PlayerDataKey.AxeTycoon)
	local woodValue = getCarryingWoodValueFromAxeTycoon(axeTycoon)
	label.Text = WoodConfig.formatWoodQuantity(woodValue)
end

-- 统计斧子总数（按 1 级斧子当量）：3 合 1 链式合成，故 n 级斧子 = 3^(n-1) 个 1 级斧子
local MERGE_INPUT_COUNT = 3

local function getTotalAxeCountFromAxeTycoon(axeTycoon: any): number
	if type(axeTycoon) ~= "table" or type(axeTycoon.axes) ~= "table" then
		return 0
	end

	local count = 0
	for _, category in axeTycoon.axes do
		local level = tonumber(category)
		if level and level >= 1 then
			count += MERGE_INPUT_COUNT ^ (level - 1)
		end
	end
	return count
end

local function refreshTotalAxeLabel()
	local label = totalAxeLabel
	if not label then
		return
	end

	local axeTycoon = PlayerDataClient.get(PlayerDataKey.AxeTycoon)
	local axeCount = getTotalAxeCountFromAxeTycoon(axeTycoon)
	label.Text = string.format("Total Inmates : %s", ShowUnitNum(axeCount))
end

-- 已发现斧子数量（图鉴解锁进度）
local function getDiscoveredAxeCount(): number
	local axeTycoon = PlayerDataClient.get(PlayerDataKey.AxeTycoon)
	if type(axeTycoon) ~= "table" or type(axeTycoon.discoveredAxes) ~= "table" then
		return 0
	end
	local count = 0
	for _ in axeTycoon.discoveredAxes do
		count += 1
	end
	return count
end

-- 刷新图鉴入口上的解锁进度（如 "5/24"）
local function refreshIndexAmount()
	local label = indexAmountLabel
	if not label then
		return
	end
	label.Text = string.format("%d/%d", getDiscoveredAxeCount(), AXE_TOTAL)
end

-- 当前已购买的 Cash 倍率档位（0=未购买），来自服务端复制的玩家属性
local function getCashMultiplierTier(): number
	return CashMultiplierConfig.clampTier(localPlayer:GetAttribute(AttributeEnum.CashMultiplier))
end

-- 从开发者商品 ID 读取指定档位的 Robux 实价（与 ChestGui / BuyButton 一致）
local function getCashMultiplierProductPrice(tier: number): number
	local entry = CashMultiplierConfig.Tiers[tier]
	if not entry then
		return 0
	end

	local productId = StoreIdCategory.Product[entry.productKey]
	if not productId or productId <= 0 then
		return 0
	end

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
	return 0
end

-- 刷新 Cash 倍率按钮：Title 展示下一可购档位（如 "x2 Cash"），Price 展示 Robux 价格，满级隐藏入口
local function refreshCashMultiplierButton()
	local frame = cashMultiplierFrame
	local title = cashMultiplierTitle
	local priceLabel = cashMultiplierPrice
	if not frame or not title then
		return
	end

	local nextTier = CashMultiplierConfig.getNextTier(getCashMultiplierTier())
	if not nextTier then
		frame.Visible = false
		return
	end

	frame.Visible = true
	title.Text = CashMultiplierConfig.formatLabel(nextTier)
	if priceLabel then
		local robuxPrice = getCashMultiplierProductPrice(nextTier)
		priceLabel.Text = string.format(RichTextCategory.connnect, ShowUnitNum(robuxPrice), RichTextCategory.robuxSymbol)
	end
end

-- 刷新当前 Cash 倍率指示标签：倍率 > 1（已购买至少一档）时显示当前倍率，如 "x2 Cash"，否则隐藏
local function refreshCashMultiplierLabel()
	local label = cashMultiplierLabel
	if not label then
		return
	end

	local tier = getCashMultiplierTier()
	if tier <= 0 then
		label.Visible = false
		return
	end

	label.Visible = true
	label.Text = CashMultiplierConfig.formatLabel(tier)
end

-- 点击购买下一档 Cash 倍率：弹出 Robux 付款框
local function onCashMultiplierActivated()
	local nextTier = CashMultiplierConfig.getNextTier(getCashMultiplierTier())
	if not nextTier then
		return
	end

	local productId = StoreIdCategory.Product[CashMultiplierConfig.Tiers[nextTier].productKey]
	if not productId or productId <= 0 then
		warn("[HUD] CashMultiplier product id is not configured for tier " .. tostring(nextTier))
		return
	end

	local now = os.clock()
	if now - lastCashMultiplierClickAt < BaseConfig.BUTTON_DEBOUNCE then
		return
	end
	lastCashMultiplierClickAt = now

	Network.fireServer(RemoteEventKey.PurchasePending, CurrencyTypes.PriceType.Product, productId)
end

-- 当前拥有斧头数（ownedAxeCount），来自服务端复制的 AxeTycoon 数据
local function getOwnedAxeCount(): number
	local axeTycoon = PlayerDataClient.get(PlayerDataKey.AxeTycoon)
	if type(axeTycoon) ~= "table" then
		return 0
	end
	return tonumber(axeTycoon.ownedAxeCount) or 0
end

-- 刷新每档付费金钱按钮的金额文本：「+发放现金」= 倍率 × 当前拥有斧头数
local function refreshPayCash()
	local ownedAxeCount = getOwnedAxeCount()
	for tierIndex, tier in payCashTiers do
		tier.amountLabel.Text = "+" .. ShowUnitNum(CashGrantConfig.getReward(tierIndex, ownedAxeCount))
	end
end

-- 点击某档付费金钱：弹出 Robux 付款框（付费后服务端按倍率 × 拥有斧头数发放现金）
local function onPayCashActivated(productId: number)
	if productId <= 0 then
		warn("[HUD] PayCash product id is not configured")
		return
	end

	local now = os.clock()
	if now - lastPayCashClickAt < BaseConfig.BUTTON_DEBOUNCE then
		return
	end
	lastPayCashClickAt = now

	Network.fireServer(RemoteEventKey.PurchasePending, CurrencyTypes.PriceType.Product, productId)
end

-- 按配置档位克隆 Template，逐行构建付费金钱面板
local function buildPayCash(payCash: Frame)
	local template = payCash:WaitForChild("Template") :: Frame
	for tierIndex, tier in CashGrantConfig.Tiers do
		local frame = template:Clone()
		frame.Name = "Tier" .. tierIndex
		frame.LayoutOrder = tierIndex
		frame.Visible = true

		local amountLabel = frame:WaitForChild("Amount") :: TextLabel
		local button = frame:WaitForChild("Button") :: GuiButton
		local productId = StoreIdCategory.Product[tier.productKey] or 0

		button.Activated:Connect(function()
			onPayCashActivated(productId)
		end)

		payCashTiers[tierIndex] = {
			amountLabel = amountLabel,
			productId = productId,
		}
		frame.Parent = payCash
	end
end

function HUD:start()
	local gui = self:bindScreenGui()

	local left = gui:WaitForChild("Left") :: Frame
	local leftInfos = left:WaitForChild("LeftInfos") :: Frame
	cashLabel = leftInfos:WaitForChild("TextLabel") :: TextLabel
	--pendingCashLabel = cashLabel:Clone()
	--pendingCashLabel.Name = "PendingCashLabel"
	--pendingCashLabel.LayoutOrder = cashLabel.LayoutOrder + 1
	--pendingCashLabel.Parent = leftInfos

	local midBottom = gui:WaitForChild("MidBottom") :: Frame
	local woodAmount = midBottom:WaitForChild("WoodAmount") :: Frame
	woodAmountLabel = woodAmount:WaitForChild("TextLabel") :: TextLabel
	-- 拾取飘字锚定在 WoodAmount 框上方
	WoodPickupPopup.setAnchor(woodAmount)
	WoodPickupPopup.setOnPop(function()
		SoundService.SFX.Coins:Play()
	end)

	local right = gui:WaitForChild("Right") :: Frame
	local rightInfos = right:WaitForChild("RightInfos") :: Frame
	totalAxeLabel = rightInfos:WaitForChild("TotalAxeAmount") :: TextLabel

	local cashMultiplier = left:WaitForChild("CashMultiplier") :: Frame
	local button = cashMultiplier:WaitForChild("Button") :: GuiButton
	cashMultiplierFrame = cashMultiplier
	cashMultiplierButton = button
	cashMultiplierTitle = button:WaitForChild("Title") :: TextLabel
	cashMultiplierPrice = button:WaitForChild("Price") :: TextLabel
	cashMultiplierLabel = leftInfos:WaitForChild("CashMultiplier") :: TextLabel

	local payCash = leftInfos:WaitForChild("PayCash") :: Frame
	buildPayCash(payCash)

	-- 图鉴入口：点击打开斧子图鉴面板（GUI_AxeCodex），Amount 显示解锁进度
	local index = left:WaitForChild("Index") :: Frame
	local indexButton = index:WaitForChild("Button") :: GuiButton
	indexAmountLabel = index:FindFirstChild("Amount") :: TextLabel?
	indexButton.Activated:Connect(function()
		NetSignals.getSignal(TriggerSignalCategory.Client.openGui):Fire(UILayerId.GUI_AxeCodex, true)
	end)

	bindTopButtons(gui)
	bindHomeButton(gui)

	refreshCashLabel()
	--refreshPendingCashLabel()
	refreshWoodAmountLabel()
	refreshTotalAxeLabel()
	refreshCashMultiplierButton()
	refreshCashMultiplierLabel()
	refreshPayCash()
	refreshIndexAmount()
end

function HUD:listen()
	PlayerDataClient.getUpdateSignal(PlayerDataKey.Currency):Connect(function()
		refreshCashLabel()
		--local pendingLabel = pendingCashLabel
		--if pendingLabel then
		--	pendingLabel.Text = string.format(
		--		"Pending: %s",
		--		string.format(RichTextCategory.cash, ShowUnitNum(getPendingCashAmount(currency)))
		--	)
		--end
	end)

	PlayerDataClient.getUpdateSignal(PlayerDataKey.AxeTycoon):Connect(function()
		refreshWoodAmountLabel()
		refreshTotalAxeLabel()
		refreshPayCash()
		refreshIndexAmount()
	end)

	local button = cashMultiplierButton
	if button then
		button.Activated:Connect(onCashMultiplierActivated)
	end
	-- 购买成功后服务端更新属性：切换购买按钮 Title 到下一档/隐藏，并刷新当前倍率指示标签
	localPlayer:GetAttributeChangedSignal(AttributeEnum.CashMultiplier):Connect(function()
		refreshCashMultiplierButton()
		refreshCashMultiplierLabel()
	end)
end

return HUD
