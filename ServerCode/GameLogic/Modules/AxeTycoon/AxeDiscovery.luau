--!strict

--[[
	斧头图鉴发现记录（纯数据 helper，服务端）。

	维护 AxeTycoon.discoveredAxes set（{ [category]=true }）：玩家曾拥有过的斧头稀有度永久记录，
	用于图鉴 UI 区分「已解锁/未解锁」。包含购买、放置、合成途经的所有稀有度。

	所有函数直接在传入的 data 表上原地写入，返回是否发生过新增（便于调用方决定是否需要落库）。
]]

local AxeDiscovery = {}

-- 取（或初始化）discoveredAxes set
local function ensure(data: { [string]: any }): { [string]: boolean }
	local set = data.discoveredAxes
	if type(set) ~= "table" then
		set = {}
		data.discoveredAxes = set
	end
	return set
end

-- 记录单个 category，返回是否为新增
function AxeDiscovery.recordOne(data: { [string]: any }, category: string?): boolean
	if type(category) ~= "string" then
		return false
	end
	local set = ensure(data)
	if set[category] then
		return false
	end
	set[category] = true
	return true
end

-- 记录一个 category 数组（如基地占用列表），返回是否有任意新增
function AxeDiscovery.recordArray(data: { [string]: any }, categories: { string }): boolean
	local set = ensure(data)
	local changed = false
	for _, category in categories do
		if type(category) == "string" and not set[category] then
			set[category] = true
			changed = true
		end
	end
	return changed
end

-- 记录一个 category set（如合成途经集合 { [category]=true }），返回是否有任意新增
function AxeDiscovery.recordSet(data: { [string]: any }, categorySet: { [string]: boolean }): boolean
	local set = ensure(data)
	local changed = false
	for category, flagged in categorySet do
		if flagged and type(category) == "string" and not set[category] then
			set[category] = true
			changed = true
		end
	end
	return changed
end

return AxeDiscovery
