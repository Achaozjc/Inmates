local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
local Button = require(script.Parent.Button)

local ColorEnum = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Enums.ColorEnum)

local Signal = require(ReplicatedStorage.ReplicatedCode.Framework.Packages.Signal)

local RichTextCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.RichTextCategory)

local NetSignals = require(ReplicatedStorage.ReplicatedCode.Framework.Core.Network.NetSignals)
local TriggerSignalCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.TriggerSignalCategory)

local Network = require(ReplicatedStorage.ReplicatedCode.Framework.Core.Network)
local RemoteEventName = require(ReplicatedStorage.ReplicatedCode.Framework.Core.Network.RemoteName.RemoteEventName)
local GUI_SurePurchase = require(ReplicatedStorage.ReplicatedCode.GameLogic.Guis.GUI_SurePurchase)

local DevProductPriceList = require(ReplicatedStorage.ReplicatedCode.Framework.Effects.DevProductPriceList)
local CurrencyTypes = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Types.CurrencyTypes)
local getGamepassInfo = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Common.GetGamepassInfo)
local ShowUnitNum = require(ReplicatedStorage.ReplicatedCode.Framework.UI.ShowUnitNum)

type Callback = (...any) -> ...any

local BuyButton = {}
BuyButton.__index = BuyButton

export type ClassType = typeof(setmetatable(
	{} :: {
		buttons: GuiObject,
		purchaseButton: GuiButton,
		giftButton: GuiButton,

		pricing: CurrencyTypes.Pricing,
		price: number,

		purchaseCallback: Callback?,
		giftCallback: Callback?,
		giftConnection: RBXScriptConnection?,
		shouldSkipConfirm: (() -> boolean)?,
	},
	BuyButton
))

function BuyButton.new(Buttons: any, pricing: CurrencyTypes.Pricing): ClassType
	local self = {}
	setmetatable(self, BuyButton)
	self.buttons = Buttons
	self.price = 0
	self.purchaseButton = Buttons:FindFirstChild("PurchaseButton")
	self.giftButton = Buttons:FindFirstChild("GiftButton")
	self.pricing = pricing
	self.purchaseCallback = nil
	self.giftCallback = nil
	self.giftConnection = nil
	self.shouldSkipConfirm = nil

	self:setup()

	self:listen()

	return self
end

function BuyButton.updatePricing(self: ClassType, pricing: CurrencyTypes.Pricing)
	self.pricing = pricing
	self:setup()
end

function BuyButton.setCallback(self: ClassType, callback)
	self.purchaseCallback = callback
end

function BuyButton.setGiftCallback(self: ClassType, callback)
	self.giftCallback = callback
end

function BuyButton.setShouldSkipConfirm(self: ClassType, callback: (() -> boolean)?)
	self.shouldSkipConfirm = callback
end

local function getDevProductPrice(productId: number): number
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

local function _findAncestorByName(root: Instance?, targetName: string): Instance?
	local current = root
	while current do
		if current.Name == targetName then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function _collectSimpleDescription(purchaseButton: GuiButton, pricing: CurrencyTypes.Pricing): string
	local container = purchaseButton.Parent
	local nameText = "this item"
	local desText = ""

	if container then
		local ownerPanel = container.Parent
		if ownerPanel then
			local infoPanel = ownerPanel:FindFirstChild("Info")
			if infoPanel and infoPanel:IsA("GuiObject") then
				local nameLabel = infoPanel:FindFirstChild("NameLabel")
				if nameLabel and nameLabel:IsA("TextLabel") and nameLabel.Text ~= "" then
					nameText = nameLabel.Text
				end
				local desLabel = infoPanel:FindFirstChild("DesLabel")
				if desLabel and desLabel:IsA("TextLabel") and desLabel.Text ~= "" then
					desText = desLabel.Text
				end
			else
				local nameLabel = ownerPanel:FindFirstChild("NameLabel", true)
				if nameLabel and nameLabel:IsA("TextLabel") and nameLabel.Text ~= "" then
					nameText = nameLabel.Text
				end
			end
		end
	end

	local priceText = ""
	local buttonLabel = purchaseButton:FindFirstChild("TextLabel")
	if buttonLabel and buttonLabel:IsA("TextLabel") and buttonLabel.Text ~= "" then
		priceText = buttonLabel.Text
	elseif pricing.price and pricing.price > 0 then
		priceText = tostring(pricing.price)
	end

	if priceText ~= "" and desText ~= "" then
		return string.format("Are you sure you would like to purchase %s for %s?\n%s", nameText, priceText, desText)
	end
	if priceText ~= "" then
		return string.format("Are you sure you would like to purchase %s for %s?", nameText, priceText)
	end
	if desText ~= "" then
		return string.format("Are you sure you would like to purchase %s?\n%s", nameText, desText)
	end
	return string.format("Are you sure you would like to purchase %s?", nameText)
end

function BuyButton.setup(self: ClassType)
	if self.pricing.priceType == CurrencyTypes.PriceType.InExperience then
		self.price = self.pricing.price
		self.purchaseButton.TextLabel.Text = string.format(RichTextCategory.cash, ShowUnitNum(self.price))
	elseif self.pricing.priceType == CurrencyTypes.PriceType.Product then
		self.price = getDevProductPrice(self.pricing.productId)
		self.purchaseButton.TextLabel.Text = string.format(RichTextCategory.robuxSymbol, self.price)
		self.purchaseButton.TextLabel.TextColor3 = ColorEnum.colors.Blue
		self.purchaseButton.UIStroke.Color = ColorEnum.colors.Blue
	elseif self.pricing.priceType == CurrencyTypes.PriceType.GamePass then
		--gamepass
		local productInfo = getGamepassInfo(self.pricing.gamepassId)
		self.price = productInfo and productInfo.PriceInRobux or 0
		self.purchaseButton.TextLabel.Text = string.format(RichTextCategory.robuxSymbol, self.price)
		self.purchaseButton.TextLabel.TextColor3 = ColorEnum.colors.Orange
		self.purchaseButton.UIStroke.Color = ColorEnum.colors.Orange
	end

	self:gift()
end

function BuyButton.getPrice(self: ClassType)
	return self.price
end

function BuyButton.setVisible(self: ClassType, visible: boolean)
	self.buttons.Visible = visible
end

function BuyButton.listen(self: ClassType)
	self.purchaseButton.Activated:Connect(function()
		if self.pricing.priceType == CurrencyTypes.PriceType.Product then
			if self.purchaseCallback then
				-- 有 callback 时优先调用（用于需要携带额外意图的场景，如附魔需要传递 rodKey）
				self.purchaseCallback()
				return
			end
			Network.fireServer(RemoteEventName.PurchasePending, CurrencyTypes.PriceType.Product, self.pricing.productId)
		elseif self.pricing.priceType == CurrencyTypes.PriceType.GamePass then
			Network.fireServer(
				RemoteEventName.PurchasePending,
				CurrencyTypes.PriceType.GamePass,
				self.pricing.gamepassId
			)
		else
			-- InExperience 类型走游戏内货币回调
			if self.purchaseCallback then
				if self.shouldSkipConfirm and self.shouldSkipConfirm() then
					self.purchaseCallback()
					return
				end
				local des = _collectSimpleDescription(self.purchaseButton, self.pricing)
				GUI_SurePurchase:prompt(des, function()
					self.purchaseCallback()
				end)
			end
		end
	end)
end

function BuyButton.gift(self: ClassType)
	if self.pricing.gift then
		self.giftButton.Visible = true
		if self.giftConnection then
			self.giftConnection:Disconnect()
			self.giftConnection = nil
		end
		self.giftConnection = self.giftButton.Activated:Connect(function()
			NetSignals.getSignal(TriggerSignalCategory.Client.gift):Fire(
				--回调
				function(recipientId)
					if self.giftCallback then
						self.giftCallback(recipientId)
						return
					end
					local giftPriceType = self.pricing.priceType
					local giftId = self.pricing.productId
					if self.pricing.priceType == CurrencyTypes.PriceType.GamePass then
						giftPriceType = CurrencyTypes.PriceType.Product
					end
					Network.fireServer(RemoteEventName.PurchasePending, giftPriceType, giftId, recipientId)
				end
			)
		end)
	else
		self.giftButton.Visible = false
		if self.giftConnection then
			self.giftConnection:Disconnect()
			self.giftConnection = nil
		end
	end
end

function BuyButton.destroy(self: ClassType) end

return BuyButton
