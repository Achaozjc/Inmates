--!strict

local StoreEnum = {}

export type Pricing = {
	priceType: string,
	productId: number?,
	gamepassId: number?,
	gift: boolean?,
}

export type StoreItem = {
	name: string?,
	des: string?,
	pricing: Pricing?,
	pricings: { [string]: { pricing: Pricing } }?,
	rewards: any?,
}

export type StoreData = {
	[string]: { [string]: StoreItem },
}

-- 新项目默认不继承旧项目商品。需要付费项时在这里按 StoreCategory 填入。
local StoreData: StoreData = {}

StoreEnum.Store = StoreData

type StoreIdEntry = {
	storeCategory: string,
	itemKey: string,
	pricingKey: string?,
	productId: number?,
	gamepassId: number?,
}

local StoreIdMapByKey: { [string]: StoreIdEntry } = {}
StoreEnum.StoreIdMapByKey = StoreIdMapByKey

local function rebuildStoreIdMapByKey()
	table.clear(StoreIdMapByKey)

	for storeCategory, items in pairs(StoreEnum.Store) do
		for itemKey, itemData in pairs(items) do
			local baseKey = string.format("%s.%s", tostring(storeCategory), tostring(itemKey))

			if itemData.pricing then
				StoreIdMapByKey[baseKey] = {
					storeCategory = tostring(storeCategory),
					itemKey = tostring(itemKey),
					pricingKey = nil,
					productId = itemData.pricing.productId,
					gamepassId = itemData.pricing.gamepassId,
				}
			end

			if itemData.pricings then
				for pricingKey, pricingData in pairs(itemData.pricings) do
					if pricingData.pricing then
						StoreIdMapByKey[string.format("%s.%s", baseKey, tostring(pricingKey))] = {
							storeCategory = tostring(storeCategory),
							itemKey = tostring(itemKey),
							pricingKey = tostring(pricingKey),
							productId = pricingData.pricing.productId,
							gamepassId = pricingData.pricing.gamepassId,
						}
					end
				end
			end
		end
	end
end

rebuildStoreIdMapByKey()

function StoreEnum.GetStoreIdMapByKey()
	return StoreIdMapByKey
end

function StoreEnum.GetPricing(storeCategory: string, itemKey: string): Pricing?
	local category = StoreEnum.Store[storeCategory]
	local itemData = category and category[itemKey]
	return itemData and itemData.pricing or nil
end

function StoreEnum.ReturnProductInfoById(productId: number): (string?, string?, StoreItem?)
	for categoryKey, categoryTable in pairs(StoreEnum.Store) do
		for itemKey, itemData in pairs(categoryTable) do
			if itemData.pricing and itemData.pricing.productId == productId then
				return categoryKey, tostring(itemKey), itemData
			end

			if itemData.pricings then
				for _, pricingData in pairs(itemData.pricings) do
					if pricingData.pricing and pricingData.pricing.productId == productId then
						return categoryKey, tostring(itemKey), pricingData :: any
					end
				end
			end
		end
	end

	return nil, nil, nil
end

function StoreEnum.ReturnGamepass(id: any): StoreItem?
	local gamepasses = StoreEnum.Store.Gamepass
	return gamepasses and gamepasses[id] or nil
end

function StoreEnum.ReturnProductInfo(storeCategory: string, itemKey: string): StoreItem?
	local category = StoreEnum.Store[storeCategory]
	return category and category[itemKey] or nil
end

return StoreEnum
