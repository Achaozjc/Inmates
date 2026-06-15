--!strict

--[[
	斧子合成纯数据逻辑（无模型操作）。

	3 把同稀有度 → 1 把高一级，从 rarity 1 到 23 链式重复，与 AxeService 原槽位合成规则一致。
	输出按稀有度降序排列，供 Base.applyAxeCategories 一次性放置。
]]

local MERGE_INPUT_COUNT = 3
local MAX_MERGE_RARITY = 23

local AxeMergeLogic = {}

function AxeMergeLogic.countFromCategories(categories: { string }): { [string]: number }
	local counts: { [string]: number } = {}
	for _, category in categories do
		counts[category] = (counts[category] or 0) + 1
	end
	return counts
end

function AxeMergeLogic.canMerge(counts: { [string]: number }): boolean
	for rarity = 1, MAX_MERGE_RARITY do
		if (counts[tostring(rarity)] or 0) >= MERGE_INPUT_COUNT then
			return true
		end
	end
	return false
end

-- 模拟合成，并额外返回过程中产出过的所有 category 集合（含被完全消耗的中间稀有度），
-- 供图鉴 discoveredAxes 记录「途经稀有度」。
function AxeMergeLogic.simulateMergeTracked(
	counts: { [string]: number }
): ({ [string]: number }, { [string]: boolean })
	local result: { [string]: number } = {}
	for category, count in counts do
		result[category] = count
	end

	local produced: { [string]: boolean } = {}
	local changed = true
	while changed do
		changed = false
		for rarity = 1, MAX_MERGE_RARITY do
			local category = tostring(rarity)
			local nextCategory = tostring(rarity + 1)
			while (result[category] or 0) >= MERGE_INPUT_COUNT do
				result[category] -= MERGE_INPUT_COUNT
				if result[category] <= 0 then
					result[category] = nil
				end
				result[nextCategory] = (result[nextCategory] or 0) + 1
				produced[nextCategory] = true
				changed = true
			end
		end
	end

	return result, produced
end

function AxeMergeLogic.simulateMerge(counts: { [string]: number }): { [string]: number }
	local result = AxeMergeLogic.simulateMergeTracked(counts)
	return result
end

function AxeMergeLogic.countsToSortedCategories(counts: { [string]: number }): { string }
	local categories: { string } = {}
	for category, count in counts do
		if count > 0 then
			for _ = 1, count do
				categories[#categories + 1] = category
			end
		end
	end

	table.sort(categories, function(a: string, b: string)
		return (tonumber(a) or 0) > (tonumber(b) or 0)
	end)

	return categories
end

-- 输入当前各斧 category 列表，返回链式合成后按稀有度降序的 category 列表
function AxeMergeLogic.mergeCategories(categories: { string }): { string }
	local mergedCounts = AxeMergeLogic.simulateMerge(AxeMergeLogic.countFromCategories(categories))
	return AxeMergeLogic.countsToSortedCategories(mergedCounts)
end

-- 同 mergeCategories，但额外返回合成过程中产出过的所有 category 集合（含中间稀有度）
function AxeMergeLogic.mergeCategoriesTracked(categories: { string }): ({ string }, { [string]: boolean })
	local mergedCounts, produced = AxeMergeLogic.simulateMergeTracked(AxeMergeLogic.countFromCategories(categories))
	return AxeMergeLogic.countsToSortedCategories(mergedCounts), produced
end

return AxeMergeLogic
