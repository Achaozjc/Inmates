--!strict

--[[
	宝箱运行时状态（服务端权威，纯内存）。

	记录各玩家堆叠区已生成、尚未消失的宝箱：每个宝箱占用 ChestPlace 下一个槽位（1..PLACE_LIMIT），
	达到上限后不再生成。与木头一样仅维护数据，宝箱模型只存在于客户端。

	纯内存、掉线丢失可接受（重建成本低）；供宝箱生产 / 后续开箱复用。
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChestConfig = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Configs.ChestConfig)

local ChestState = {}

export type ChestEntry = {
	id: number, -- 全局唯一编号，客户端据此定位/移除模型
	category: string, -- 宝箱等级（ChestCategory 值）
	slot: number, -- 占用的 ChestPlace 槽位（1..PLACE_LIMIT）
	spawnTime: number, -- 生成时刻（os.clock）
}

-- UserId -> { ChestEntry }
local chestsByUserId: { [number]: { ChestEntry } } = {}
local nextId = 0

-- 取某玩家当前宝箱列表（内部引用，勿外部篡改）
local function getList(userId: number): { ChestEntry }
	local list = chestsByUserId[userId]
	if not list then
		list = {}
		chestsByUserId[userId] = list
	end
	return list
end

-- 当前宝箱数量
function ChestState.count(userId: number): number
	local list = chestsByUserId[userId]
	return if list then #list else 0
end

-- 选取最小的空闲槽位（1..PLACE_LIMIT），无空闲返回 nil
local function pickFreeSlot(list: { ChestEntry }): number?
	local used: { [number]: boolean } = {}
	for _, entry in list do
		used[entry.slot] = true
	end
	for slot = 1, ChestConfig.PLACE_LIMIT do
		if not used[slot] then
			return slot
		end
	end
	return nil
end

-- 新增一个宝箱；满仓（达到 PLACE_LIMIT）返回 nil
function ChestState.addChest(userId: number, category: string): ChestEntry?
	local list = getList(userId)
	local slot = pickFreeSlot(list)
	if not slot then
		return nil
	end

	nextId += 1
	local entry: ChestEntry = {
		id = nextId,
		category = category,
		slot = slot,
		spawnTime = os.clock(),
	}
	list[#list + 1] = entry
	return entry
end

-- 移除指定 id 的宝箱；返回被移除的条目（不存在返回 nil）
function ChestState.removeChest(userId: number, id: number): ChestEntry?
	local list = chestsByUserId[userId]
	if not list then
		return nil
	end
	for index, entry in list do
		if entry.id == id then
			table.remove(list, index)
			if #list == 0 then
				chestsByUserId[userId] = nil
			end
			return entry
		end
	end
	return nil
end

-- 取某玩家所有宝箱（返回副本）
function ChestState.getChests(userId: number): { ChestEntry }
	local list = chestsByUserId[userId]
	local copy: { ChestEntry } = {}
	if list then
		for index, entry in list do
			copy[index] = entry
		end
	end
	return copy
end

-- 清空某玩家所有宝箱（离开时调用）
function ChestState.clear(userId: number)
	chestsByUserId[userId] = nil
end

return ChestState
