--!strict

export type SortableItem = {
	rarity: number?,
	count: number?,
	weight: number?,
	acquiredAt: number?,
	mutation: string?,
}

local sortUtil = {}

local function getNumber(item: SortableItem, key: string): number
	local value = (item :: any)[key]
	return if type(value) == "number" then value else 0
end

local function byRarityThenCount(a: SortableItem, b: SortableItem): boolean
	local rarityA = getNumber(a, "rarity")
	local rarityB = getNumber(b, "rarity")
	if rarityA ~= rarityB then
		return rarityA > rarityB
	end
	return getNumber(a, "count") > getNumber(b, "count")
end

sortUtil["Last Acquired"] = function(a: SortableItem, b: SortableItem): boolean
	local acquiredA = getNumber(a, "acquiredAt")
	local acquiredB = getNumber(b, "acquiredAt")
	if acquiredA ~= acquiredB then
		return acquiredA > acquiredB
	end
	return byRarityThenCount(a, b)
end

sortUtil.Mutation = function(a: SortableItem, b: SortableItem): boolean
	local mutationA = tostring(a.mutation or "")
	local mutationB = tostring(b.mutation or "")
	if mutationA ~= mutationB then
		return mutationA < mutationB
	end
	return byRarityThenCount(a, b)
end

sortUtil.Weight = function(a: SortableItem, b: SortableItem): boolean
	local weightA = getNumber(a, "weight")
	local weightB = getNumber(b, "weight")
	if weightA ~= weightB then
		return weightA > weightB
	end
	return getNumber(a, "count") > getNumber(b, "count")
end

sortUtil.Rarity = byRarityThenCount

return sortUtil
