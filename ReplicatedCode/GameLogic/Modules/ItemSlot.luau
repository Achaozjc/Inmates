--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Connections = require(ReplicatedStorage.ReplicatedCode.Framework.Infrastructure.Classes.Connections)
local ColorEnum = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Enums.ColorEnum)
local CategoryConfig = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Configs.CategoryConfig)
local RichTextCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.RichTextCategory)
local TypeCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.TypeCategory)
local IconCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.IconCategory)
local getCodeAsset = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Instance.GetCodeAsset)

local ItemSlot = {}
ItemSlot.__index = ItemSlot

export type ClassType = typeof(setmetatable(
	{} :: {
		itemKey: string,
		slotFrame: any,
		highlightFrame: any,

		connections: Connections.ClassType,
		count: number,

		rarity: number,
		equip: boolean,
		info: any,
	},
	ItemSlot
))

function ItemSlot.new(itemKey: string, count: number): ClassType
	local self = {
		itemKey = itemKey,
		connections = Connections.new(),
		count = count,
		weight = 1,
		acquired = 0,
		favorite = false,
	}

	setmetatable(self, ItemSlot)

	self.slotFrame = (getCodeAsset("Components", "ItemSlotTemplate") :: GuiObject):Clone()

	self.highlightFrame = self.slotFrame:WaitForChild("HighlightFrame") :: any

	self.info = CategoryConfig.getTypeInfo(TypeCategory.Item, itemKey)
	self.rarity = self.info.rarity

	self.equip = self.info.equip

	self:setLayoutOrder(self.rarity)

	self:assignToolData()

	self:listen()

	return self
end

function ItemSlot.assignToolData(self: ClassType)
	local rarityColor = ColorEnum.SingleRarityColor[self.rarity]
	self.slotFrame.Rarity.BackgroundColor3 = rarityColor
	self.slotFrame.Rarity.Visible = true

	self.highlightFrame.UIStroke.Color = rarityColor
	self.highlightFrame.Icon.ImageColor3 = rarityColor

	local iconId = self.info.icon
	if iconId == nil or iconId == "" then
		local bucket = IconCategory.Items
		if bucket then
			iconId = bucket[self.itemKey] or ""
		end
	end
	self.slotFrame.Icon.Image = iconId

	self.slotFrame.ToolName.Text = self.info.name

	self.slotFrame.Name = self.info.name

	self.slotFrame.CountLabel.Text = self.count > 0 and string.format(RichTextCategory.count, self.count) or ""
end

function ItemSlot.updateData(self: ClassType, count: number)
	self.count = count
	self.slotFrame.CountLabel.Text = self.count > 0 and string.format(RichTextCategory.count, self.count) or ""
end

function ItemSlot.setHighlightFrame(self: ClassType, visible: boolean)
	self.highlightFrame.Visible = visible
end

function ItemSlot.setVisible(self: ClassType, visible: boolean)
	self.slotFrame.Visible = visible
end

function ItemSlot.setParent(self: ClassType, parent: GuiObject)
	self.slotFrame.Parent = parent
end

function ItemSlot.setLayoutOrder(self: ClassType, listOrder: number)
	self.slotFrame.LayoutOrder = listOrder
	self.slotFrame.SelectionOrder = listOrder
end

function ItemSlot.listen(self: ClassType) end

function ItemSlot.destroy(self: ClassType)
	self.connections:disconnect()
	self.slotFrame:Destroy()
end

return ItemSlot
