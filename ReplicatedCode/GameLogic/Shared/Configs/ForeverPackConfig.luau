local ReplicatedStorage = game:GetService("ReplicatedStorage")


local getNextDayTimestamp = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Time.GetNextDayTimestamp)
local StoreEnum = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Enums.StoreEnum)
local StoreCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.StoreCategory)

local ForeverPackConfig = {}

local rewardsList = {
	free = {
	
	},
	paid = {
	
	}
}

local _RNG: Random? = nil




local function initializeRandomSeed(index: number)
	local seed = getNextDayTimestamp() + index  
	_RNG = Random.new(seed)
end


--local function getRandom(selectedRewards)
--	local rng = Random.new()
--	local randIndex = rng:NextInteger(1, #selectedRewards)
--	return selectedRewards[randIndex]
--end


local function getWeightedRandom(selectedRewards)
	local totalWeight = 0
	for _, reward in ipairs(selectedRewards) do
		totalWeight = totalWeight + reward.weight
	end

	local rng = _RNG or Random.new()
	local rand = rng:NextNumber() * totalWeight
	local cumulative = 0

	for _, reward in ipairs(selectedRewards) do
		cumulative = cumulative + reward.weight
		if rand <= cumulative then
			return reward
		end
	end
end


function ForeverPackConfig.isPaid(index: number)
	return (index + 2) % 4 == 0
end



function ForeverPackConfig.getForeverProduceInfo(index: number)
	local totalIds = #StoreEnum.Store[StoreCategory.ForeverPack]
	
	local payIdIndex = math.floor((index - 2) / 12) + 1

	-- 如果超出范围，取最后一个
	if payIdIndex > totalIds then
		payIdIndex = totalIds
	end
	
	return StoreEnum.Store[StoreCategory.ForeverPack][payIdIndex]
end


function ForeverPackConfig.getForeverPack(index: number)
	-- 在每次刷新前调用
	initializeRandomSeed(index)

	local isPaid = ForeverPackConfig.isPaid(index)
	
	local selectedRewards = isPaid and rewardsList.paid or rewardsList.free

	return getWeightedRandom(selectedRewards)
end

return ForeverPackConfig
