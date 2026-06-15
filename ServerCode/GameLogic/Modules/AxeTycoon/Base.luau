--!strict

--[[
	玩家基地运行时对象（参考 dingdong 项目 Base 模式简化而来）。

	职责：分配给玩家时在脚本中「构建」基地，为放置斧子做好准备：
	- 枚举 AxeMachine.Floors.Floor_1..10 下的 Attachment（每层 10 个，共 100 槽）构建 Slot
	- 绑定每层对应的 Axes.Floor_N 折叠作为模型父级
	- 清场：移除遗留斧头模型，保证干净初始态
	- rebuildFromData：按持久化 AxeTycoon.axes 重建已有斧头（重连/重分配时还原）
	- refreshFloorTransparency：Floor_2..10 始终全透明（Floor_1 始终可见）

	实例结构由 Studio 维护，本模块只读取并填充逻辑层。
]]

local Slot = require(script.Parent.Slot)

local Base = {}
Base.__index = Base

local FLOOR_COUNT = 10
local SLOTS_PER_FLOOR = 10

export type ClassType = typeof(setmetatable(
	{} :: {
		_instance: Folder,
		_owner: Player,
		_axeMachine: Model,
		_axesFolder: Folder,
		_floorParts: { [number]: BasePart }, -- floor 编号 -> Floors.Floor_N Part
		_slots: { [string]: Slot.ClassType }, -- key "floor_index" -> Slot
	},
	Base
))

local EMPTY_FLOOR_TRANSPARENCY = 1

function Base.new(instance: Folder, owner: Player): ClassType
	local self = setmetatable({
		_instance = instance,
		_owner = owner,
		_floorParts = {},
		_slots = {},
	}, Base)
	self:_setup()
	return self
end

function Base._setup(self: ClassType)
	local axeMachine = self._instance:FindFirstChild("InmateMachine") :: Model?
	assert(axeMachine, string.format("[Base] %s 缺少 InmateMachine", self._instance:GetFullName()))
	self._axeMachine = axeMachine

	local floorsFolder = axeMachine:FindFirstChild("Floors")
	local axesFolder = axeMachine:FindFirstChild("Inmates")
	assert(floorsFolder and axesFolder, "[Base] InmateMachine 缺少 Floors 或 Inmates 折叠")
	self._axesFolder = axesFolder :: Folder

	-- 枚举楼层与槽位 attachment 构建 Slot
	for floor = 1, FLOOR_COUNT do
		local floorPart = floorsFolder:FindFirstChild("Floor_" .. floor)
		local axesFloor = axesFolder:FindFirstChild("Floor_" .. floor)
		if floorPart and floorPart:IsA("BasePart") then
			self._floorParts[floor] = floorPart
		end
		if not floorPart or not axesFloor or not axesFloor:IsA("Folder") then
			continue
		end
		for index = 1, SLOTS_PER_FLOOR do
			-- 新美术里 Attachment 全局连续编号（Floor_1: 1..10、Floor_2: 11..20 …），
			-- 而槽位 key 仍用 floor_index（1..10）以兼容持久化数据
			local attachmentName = (floor - 1) * SLOTS_PER_FLOOR + index
			local attachment = floorPart:FindFirstChild(tostring(attachmentName))
			if attachment and attachment:IsA("Attachment") then
				local slot = Slot.new(floor, index, attachment, axesFloor)
				self._slots[slot:getKey()] = slot
			end
		end
	end

	-- 清场：移除 Axes 折叠下任何遗留模型，保证干净初始态
	self:_clearAllModels()
	self:refreshFloorTransparency()
end

-- 直接清空 Axes 折叠下所有遗留实例（与 Slot 状态无关的兜底清理）
function Base._clearAllModels(self: ClassType)
	for _, axesFloor in self._axesFolder:GetChildren() do
		if axesFloor:IsA("Folder") then
			for _, child in axesFloor:GetChildren() do
				child:Destroy()
			end
		end
	end
end

function Base.getOwner(self: ClassType): Player
	return self._owner
end

function Base.getInstance(self: ClassType): Folder
	return self._instance
end

function Base.getSlot(self: ClassType, key: string): Slot.ClassType?
	return self._slots[key]
end

-- 按 floor、index 升序返回全部槽位 key（同一层从左到右，层与层从前到后）
function Base.getOrderedSlotKeys(self: ClassType): { string }
	local keys: { string } = {}
	for floor = 1, FLOOR_COUNT do
		for index = 1, SLOTS_PER_FLOOR do
			local key = string.format("%d_%d", floor, index)
			if self._slots[key] then
				keys[#keys + 1] = key
			end
		end
	end
	return keys
end

-- 按 floor、index 顺序返回所有空槽 key（供购买斧子时分配）
function Base.getEmptySlotKeys(self: ClassType): { string }
	local keys: { string } = {}
	for _, key in self:getOrderedSlotKeys() do
		local slot = self._slots[key]
		if slot and not slot:isOccupied() then
			keys[#keys + 1] = key
		end
	end
	return keys
end

-- 返回所有已占用槽位的 { key, model, category }，供木头生产服务枚举斧子
export type OccupiedSlot = { key: string, model: Model, category: string }
function Base.getOccupiedSlots(self: ClassType): { OccupiedSlot }
	local result: { OccupiedSlot } = {}
	for key, slot in self._slots do
		local model = slot:getModel()
		local category = slot:getAxeCategory()
		if model and category then
			result[#result + 1] = { key = key, model = model, category = category }
		end
	end
	return result
end

function Base.getOccupiedCount(self: ClassType): number
	local count = 0
	for _, slot in self._slots do
		if slot:isOccupied() then
			count += 1
		end
	end
	return count
end

-- 当前已放置斧子的 category 列表（不含槽位 key）
function Base.getOccupiedCategories(self: ClassType): { string }
	local categories: { string } = {}
	for _, occupied in self:getOccupiedSlots() do
		categories[#categories + 1] = occupied.category
	end
	return categories
end

-- 清空后按顺序一次性放置（左对齐；调用方负责排序）
function Base.applyAxeCategories(self: ClassType, categories: { string })
	for _, slot in self._slots do
		slot:clearAxe()
	end

	local orderedKeys = self:getOrderedSlotKeys()
	for index, category in categories do
		local key = orderedKeys[index]
		local slot = if key then self._slots[key] else nil
		if slot then
			slot:placeAxe(category)
		end
	end

	self:refreshFloorTransparency()
end

-- Floor_2..10：始终隐藏（不再根据有无斧子显示）；Floor_1 不参与
function Base.refreshFloorTransparency(self: ClassType)
	for floor = 2, FLOOR_COUNT do
		local part = self._floorParts[floor]
		if part then
			part.Transparency = EMPTY_FLOOR_TRANSPARENCY
		end
	end
end

-- 重排已放置斧子：向左紧凑对齐，槽位从左到右按稀有度从高到低（category 数值降序）
function Base.relayoutAxesByRarityDesc(self: ClassType)
	local categories = self:getOccupiedCategories()
	table.sort(categories, function(a: string, b: string)
		return (tonumber(a) or 0) > (tonumber(b) or 0)
	end)
	self:applyAxeCategories(categories)
end

-- 按持久化数据重建斧头：axes 形如 { ["3_7"]="2", ... }，键为槽位、值为斧头 category
function Base.rebuildFromData(self: ClassType, axes: { [string]: string }?)
	if not axes then
		self:refreshFloorTransparency()
		return
	end
	for key, category in axes do
		local slot = self._slots[key]
		if slot and type(category) == "string" then
			slot:placeAxe(category)
		end
	end
	self:refreshFloorTransparency()
end

function Base.destroy(self: ClassType)
	for _, slot in self._slots do
		slot:clearAxe()
	end
	self:_clearAllModels()
	self:refreshFloorTransparency()
	table.clear(self._slots)
	table.clear(self._floorParts)
end

return Base
