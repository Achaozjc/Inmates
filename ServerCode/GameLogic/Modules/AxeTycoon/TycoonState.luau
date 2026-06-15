--!strict

--[[
	斧头大亨运行时状态聚合（非 Service，纯内存）。

	本模块管理「堆叠区」木头数据——斧子产出但玩家尚未背走的木头。
	按 UserId 记录各木种件数，受 BaseConfig.GROUND_STACK_LIMIT 总量上限约束。

	纯内存、掉线丢失可接受（重建成本低）；供木头生产 / 背负 / HUD 复用，避免循环依赖。
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseConfig = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Configs.BaseConfig)

local TycoonState = {}

-- UserId -> { [woodCategory] = 件数 }
local groundWoodByUserId: { [number]: { [string]: number } } = {}

-- 计算某玩家堆叠区当前总件数
local function computeTotal(userId: number): number
	local byCategory = groundWoodByUserId[userId]
	if not byCategory then
		return 0
	end
	local total = 0
	for _, count in byCategory do
		total += count
	end
	return total
end

-- 向堆叠区加入 n 件指定木种；受总量上限约束，返回实际加入数量（可能小于 n，满则为 0）
function TycoonState.addGroundWood(userId: number, woodCategory: string, n: number): number
	if n <= 0 then
		return 0
	end

	local total = computeTotal(userId)
	local room = BaseConfig.GROUND_STACK_LIMIT - total
	if room <= 0 then
		return 0
	end

	local added = math.min(room, n)
	local byCategory = groundWoodByUserId[userId]
	if not byCategory then
		byCategory = {}
		groundWoodByUserId[userId] = byCategory
	end
	byCategory[woodCategory] = (byCategory[woodCategory] or 0) + added
	return added
end

-- 获取堆叠区总件数
function TycoonState.getGroundTotal(userId: number): number
	return computeTotal(userId)
end

-- 获取堆叠区各木种件数（返回副本，避免外部篡改内部表）
function TycoonState.getGroundByCategory(userId: number): { [string]: number }
	local byCategory = groundWoodByUserId[userId]
	local copy: { [string]: number } = {}
	if byCategory then
		for category, count in byCategory do
			copy[category] = count
		end
	end
	return copy
end

-- 清空某玩家堆叠区（背走 / 离开时调用）
function TycoonState.clearGround(userId: number)
	groundWoodByUserId[userId] = nil
end

-- 从堆叠区取走至多 n 件（按木种 category 字典序依次扣减）；返回实际取走的各木种件数
function TycoonState.takeGroundWood(userId: number, n: number): { [string]: number }
	if n <= 0 then
		return {}
	end

	local byCategory = groundWoodByUserId[userId]
	if not byCategory then
		return {}
	end

	local total = computeTotal(userId)
	local toTake = math.min(n, total)
	if toTake <= 0 then
		return {}
	end

	local taken: { [string]: number } = {}
	local remaining = toTake

	local categories: { string } = {}
	for category in byCategory do
		categories[#categories + 1] = category
	end
	table.sort(categories)

	for _, category in categories do
		if remaining <= 0 then
			break
		end
		local available = byCategory[category] or 0
		if available > 0 then
			local take = math.min(available, remaining)
			byCategory[category] = available - take
			if byCategory[category] <= 0 then
				byCategory[category] = nil
			end
			taken[category] = take
			remaining -= take
		end
	end

	if computeTotal(userId) <= 0 then
		groundWoodByUserId[userId] = nil
	end

	return taken
end

return TycoonState
