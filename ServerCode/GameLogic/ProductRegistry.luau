--!strict

export type ProductEntry = {
	storeCategory: string?,
	itemKey: string?,
	info: any?,
}

local ProductRegistry = {}

local productMap: { [number]: ProductEntry } = {}
ProductRegistry._map = productMap

function ProductRegistry.clear()
	table.clear(productMap)
end

function ProductRegistry.register(productId: number, entry: ProductEntry)
	if productId <= 0 then
		error("productId must be a positive number")
	end

	productMap[productId] = entry
end

function ProductRegistry.has(productId: number): boolean
	return productMap[productId] ~= nil
end

function ProductRegistry.get(productId: number): ProductEntry?
	return productMap[productId]
end

return ProductRegistry
