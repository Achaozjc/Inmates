--!strict

--[[
	Sets all BaseParts in an instance to a given CollisionGroup
	Watches for new BaseParts to be added as a descendant
	Resets the CollisionGroup if the descendant is removed
	Automatically destroys itself if the instance is destroyed
	将实例中的所有基础部件设置为给定的碰撞组
	观察是否有新的基础部件被添加为后代
	如果删除后代，重置碰撞组
	如果实例被销毁，会自动销毁自身
--]]

-- 内部用于存储每个部件被覆盖前的原始碰撞组名称的 Attribute Key
local ATTR_ORIGINAL_CG = "OriginalCollisionGroup"

local DescendantsCollisionGroup = {}
DescendantsCollisionGroup.__index = DescendantsCollisionGroup

export type ClassType = typeof(setmetatable(
	{} :: {
		_instance: Instance,
		_collisionGroup: string,
		_descendantAddedConnection: RBXScriptConnection?,
		_descendantRemovingConnection: RBXScriptConnection?,
		_isDestroyed: boolean,
		_pendingAddedParts: { BasePart },
		_pendingRemovedParts: { BasePart },
		_flushScheduled: boolean,
	},
	DescendantsCollisionGroup
))

function DescendantsCollisionGroup.new(instance: Instance, collisionGroup: string): ClassType
	local self = {
		_instance = instance,
		_collisionGroup = collisionGroup,
		_descendantAddedConnection = nil,
		_descendantRemovingConnection = nil,
		_isDestroyed = false,
		_pendingAddedParts = {},
		_pendingRemovedParts = {},
		_flushScheduled = false,
	}

	setmetatable(self, DescendantsCollisionGroup)

	self:_setupDescendants()

	return self
end

function DescendantsCollisionGroup._setCollisionGroup(self: ClassType, part: BasePart)
	if not part:IsA("BasePart") then
		return
	end
	if part:GetAttribute(ATTR_ORIGINAL_CG) then  --如果已有则不要设置了，用作tool
		return
	end
	
	part.CastShadow = false  --关闭投影
	assert(
		part:GetAttribute(ATTR_ORIGINAL_CG) == nil,
		string.format("%s already has another DescendantsCollisionGroup acting on it", part:GetFullName())
	)

	part:SetAttribute(ATTR_ORIGINAL_CG, part.CollisionGroup)
	part.CollisionGroup = self._collisionGroup
	
	local accessory = part:FindFirstAncestorWhichIsA("Accessory")
	--local tool = part:FindFirstAncestorWhichIsA("Tool")
	if accessory then
		part.CanQuery = false
	end
end

function DescendantsCollisionGroup._restoreCollisionGroup(self: ClassType, part: BasePart)
	local originalCollisionGroup = part:GetAttribute(ATTR_ORIGINAL_CG)
	if originalCollisionGroup == nil then
		return
	end
	part.CollisionGroup = tostring(originalCollisionGroup)
	part:SetAttribute(ATTR_ORIGINAL_CG, nil)
end

function DescendantsCollisionGroup._flushPending(self: ClassType)
	self._flushScheduled = false
	if self._isDestroyed then
		table.clear(self._pendingAddedParts)
		table.clear(self._pendingRemovedParts)
		return
	end

	for _, basePart in ipairs(self._pendingAddedParts) do
		if basePart:IsDescendantOf(self._instance) then
			self:_setCollisionGroup(basePart)
		end
	end
	table.clear(self._pendingAddedParts)

	for _, basePart in ipairs(self._pendingRemovedParts) do
		if not basePart:IsDescendantOf(self._instance) then
			self:_restoreCollisionGroup(basePart)
		end
	end
	table.clear(self._pendingRemovedParts)
end

function DescendantsCollisionGroup._scheduleFlush(self: ClassType)
	if self._flushScheduled or self._isDestroyed then
		return
	end
	self._flushScheduled = true
	-- 当前事件里只入队，延后合帧处理，避免在 DescendantAdded/Removing 回调栈里改部件状态。
	task.defer(function()
		if self._isDestroyed then
			self._flushScheduled = false
			return
		end
		self:_flushPending()
	end)
end

function DescendantsCollisionGroup._setupDescendants(self: ClassType)
	for _, part in ipairs(self._instance:GetDescendants()) do
		if part:IsA("BasePart") then
			self:_setCollisionGroup(part)
		end
	end

	self._descendantAddedConnection = self._instance.DescendantAdded:Connect(function(part: Instance)
		if part:IsA("BasePart") then
			table.insert(self._pendingAddedParts, part :: BasePart)
			self:_scheduleFlush()
		end
	end)

	self._descendantRemovingConnection = self._instance.DescendantRemoving:Connect(function(part: Instance)
		if part:IsA("BasePart") then
			table.insert(self._pendingRemovedParts, part :: BasePart)
			self:_scheduleFlush()
		end
	end)
end

function DescendantsCollisionGroup.destroy(self: ClassType)
	if self._isDestroyed then
		return
	end
	self._isDestroyed = true
	if self._descendantAddedConnection then
		self._descendantAddedConnection:Disconnect()
		self._descendantAddedConnection = nil
	end
	if self._descendantRemovingConnection then
		self._descendantRemovingConnection:Disconnect()
		self._descendantRemovingConnection = nil
	end
	table.clear(self._pendingAddedParts)
	table.clear(self._pendingRemovedParts)
	self._flushScheduled = false
	-- 先恢复当前所有后代的碰撞组并清除占位属性，避免实例入池复用时仍带 OriginalCollisionGroup 导致不再被设成新组
	for _, d in ipairs(self._instance:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute(ATTR_ORIGINAL_CG) then
			self:_restoreCollisionGroup(d :: BasePart)
		end
	end
end

return DescendantsCollisionGroup
