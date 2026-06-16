--!strict

--[[
	斧头大亨运行时状态聚合（非 Service，纯内存）。

	本模块管理「堆叠区」木头数据——斧子产出但玩家尚未背走的木头。
	以「单件队列」按产出顺序记录每件木头的木种与成熟时刻（matureAt）：
	  matureAt = 产出时刻 + 落地延迟，到点后该件才算「已落入堆叠区」，可被自动收集通行证收取。
	受 BaseConfig.GROUND_STACK_LIMIT 总量上限约束。

	纯内存、掉线丢失可接受（重建成本低）；供木头生产 / 背负 / HUD 复用，避免循环依赖。
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseConfig = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Configs.BaseConfig)

local TycoonState = {}

-- 单件木头记录：木种 + 成熟时刻（os.clock 时间轴）
type GroundEntry = { category: string, matureAt: number }

-- UserId -> 木头单件队列（按产出顺序，越早产出越靠前）
local groundByUserId: { [number]: { GroundEntry } } = {}

-- 计算某玩家堆叠区当前总件数
local function computeTotal(userId: number): number
	local list = groundByUserId[userId]
	return if list then #list else 0
end

-- 按 need 明细从队列前往后移除对应件数；matureOnly 为 true 时只移除已成熟件
-- 返回实际移除的各木种件数；会就地修改并在清空时回收
local function removeByCounts(
	userId: number,
	need: { [string]: number },
	matureOnly: boolean,
	now: number
): { [string]: number }
	local list = groundByUserId[userId]
	if not list then
		return {}
	end

	local taken: { [string]: number } = {}
	local newList: { GroundEntry } = {}
	for _, entry in list do
		local left = need[entry.category]
		local eligible = left ~= nil and left > 0 and (not matureOnly or entry.matureAt <= now)
		if eligible then
			need[entry.category] = left - 1
			taken[entry.category] = (taken[entry.category] or 0) + 1
		else
			newList[#newList + 1] = entry
		end
	end

	groundByUserId[userId] = if #newList > 0 then newList else nil
	return taken
end

-- 向堆叠区加入 n 件指定木种；受总量上限约束，返回实际加入数量（可能小于 n，满则为 0）
-- landDelay：落地延迟（秒），加入后需经过此时长该件才算成熟、可被自动收集；默认 0（立即成熟）
function TycoonState.addGroundWood(userId: number, woodCategory: string, n: number, landDelay: number?): number
	if n <= 0 then
		return 0
	end

	local total = computeTotal(userId)
	local room = BaseConfig.GROUND_STACK_LIMIT - total
	if room <= 0 then
		return 0
	end

	local added = math.min(room, n)
	local list = groundByUserId[userId]
	if not list then
		list = {}
		groundByUserId[userId] = list
	end

	local matureAt = os.clock() + (landDelay or 0)
	for _ = 1, added do
		list[#list + 1] = { category = woodCategory, matureAt = matureAt }
	end
	return added
end

-- 获取堆叠区总件数
function TycoonState.getGroundTotal(userId: number): number
	return computeTotal(userId)
end

-- 获取堆叠区已成熟（已落入堆叠区、可被自动收集）件数
function TycoonState.getMatureGroundTotal(userId: number): number
	local list = groundByUserId[userId]
	if not list then
		return 0
	end
	local now = os.clock()
	local count = 0
	for _, entry in list do
		if entry.matureAt <= now then
			count += 1
		end
	end
	return count
end

-- 获取堆叠区各木种件数（返回副本，避免外部篡改内部表）
function TycoonState.getGroundByCategory(userId: number): { [string]: number }
	local list = groundByUserId[userId]
	local copy: { [string]: number } = {}
	if list then
		for _, entry in list do
			copy[entry.category] = (copy[entry.category] or 0) + 1
		end
	end
	return copy
end

-- 清空某玩家堆叠区（背走 / 离开时调用）
function TycoonState.clearGround(userId: number)
	groundByUserId[userId] = nil
end

-- 从堆叠区按木种分别取走（各木种不超过 requested 与库存）；返回实际取走的各木种件数
function TycoonState.takeGroundWoodByCategory(userId: number, requested: { [string]: number }): { [string]: number }
	if not groundByUserId[userId] then
		return {}
	end

	local need: { [string]: number } = {}
	for category, count in requested do
		local want = math.floor(tonumber(count) or 0)
		if want > 0 then
			need[category] = want
		end
	end

	return removeByCounts(userId, need, false, 0)
end

-- 按字典序在给定可用件数内分配至多 n 件，得到各木种需取件数
local function allocByDictionary(available: { [string]: number }, n: number): { [string]: number }
	local categories: { string } = {}
	for category in available do
		categories[#categories + 1] = category
	end
	table.sort(categories)

	local need: { [string]: number } = {}
	local remaining = n
	for _, category in categories do
		if remaining <= 0 then
			break
		end
		local take = math.min(available[category], remaining)
		if take > 0 then
			need[category] = take
			remaining -= take
		end
	end
	return need
end

-- 从堆叠区取走至多 n 件（按木种 category 字典序依次扣减）；返回实际取走的各木种件数
function TycoonState.takeGroundWood(userId: number, n: number): { [string]: number }
	if n <= 0 then
		return {}
	end
	local list = groundByUserId[userId]
	if not list then
		return {}
	end

	local toTake = math.min(n, #list)
	if toTake <= 0 then
		return {}
	end

	local available: { [string]: number } = {}
	for _, entry in list do
		available[entry.category] = (available[entry.category] or 0) + 1
	end

	local need = allocByDictionary(available, toTake)
	return removeByCounts(userId, need, false, 0)
end

-- 仅从「已成熟」木头中取走至多 n 件（按木种 category 字典序）；供自动收集通行证使用
-- 返回实际取走的各木种件数；未成熟（仍在落地中）的木头不会被取走
function TycoonState.takeMatureGround(userId: number, n: number): { [string]: number }
	if n <= 0 then
		return {}
	end
	local list = groundByUserId[userId]
	if not list then
		return {}
	end

	local now = os.clock()
	local available: { [string]: number } = {}
	local matureTotal = 0
	for _, entry in list do
		if entry.matureAt <= now then
			available[entry.category] = (available[entry.category] or 0) + 1
			matureTotal += 1
		end
	end

	local toTake = math.min(n, matureTotal)
	if toTake <= 0 then
		return {}
	end

	local need = allocByDictionary(available, toTake)
	return removeByCounts(userId, need, true, now)
end

return TycoonState
