--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IconCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.IconCategory)
local TypeCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.TypeCategory)

local CategoryConfig = {}

CategoryConfig.Items = {} :: { [string]: any }

function CategoryConfig.registerItem(itemKey: string, info: any)
	CategoryConfig.Items[itemKey] = info
end

function CategoryConfig.getTypeInfo(typeCategory: string, itemKey: string): any?
	if typeCategory == TypeCategory.Item then
		local configured = CategoryConfig.Items[itemKey]
		if configured then
			return configured
		end

		return {
			key = itemKey,
			name = tostring(itemKey),
			icon = IconCategory.Items[itemKey] or "",
			rarity = 1,
			equip = false,
		}
	end

	return nil
end

function CategoryConfig.GetPlayerMaxExp(level: number): number
	local lv = math.max(1, math.floor(level))
	return 100 + (lv - 1) * 25
end

return CategoryConfig
