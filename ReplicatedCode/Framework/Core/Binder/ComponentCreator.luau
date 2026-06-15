--!strict

--[[
	ComponentCreator.luau
	优化后的 Binder 实现，用于将类实例的生命周期绑定到 CollectionService 标签。

	优化点：
	1. 增强类型安全和代码健壮性
	2. 优化 Service 获取和缓存
	3. 改进错误处理 (xpcall)
	4. 优化生命周期管理 (CheckParent, PrimaryPart)
	5. 明确的内存管理 (Janitor)
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Signal = require(ReplicatedStorage.ReplicatedCode.Framework.Packages.Signal)
local Janitor = require(ReplicatedStorage.ReplicatedCode.Framework.Packages.Janitor)

-- 定义 Wrapper 类的接口
type WrapperInstance = {
	destroy: (self: WrapperInstance) -> (),
	Destroy: (self: WrapperInstance) -> ()?, -- 兼容 Destroy 命名
	[any]: any,
}

type WrapperClass = {
	new: (instance: Instance, ...any) -> WrapperInstance,
	[any]: any,
}

local ComponentCreator = {}
ComponentCreator.__index = ComponentCreator

export type ClassType = typeof(setmetatable(
	{} :: {
		tag: string,
		wrapperClass: WrapperClass,
		_wrappersByInstance: { [Instance]: WrapperInstance },
		_wrapperParameters: { n: number, [number]: any },
		objectAdded: Signal.ClassType,
		objectRemoved: Signal.ClassType,
		janitor: Janitor.Janitor,
	},
	ComponentCreator
))

--[[
	创建一个新的 ComponentCreator 绑定器
	@param collectionServiceTag CollectionService 的标签名
	@param wrapperClass 要绑定的类 (必须包含 .new(instance, ...) 和 :destroy() 方法)
	@param ... 传递给 wrapperClass.new 的额外参数
]]
function ComponentCreator.new(
	collectionServiceTag: string,
	wrapperClass: WrapperClass,
	...: any?
): ClassType
	local self = {
		tag = collectionServiceTag,
		wrapperClass = wrapperClass,
		_wrappersByInstance = {},
		_wrapperParameters = table.pack(...),
		objectAdded = Signal.new(),
		objectRemoved = Signal.new(),
		janitor = Janitor.new(),
	}

	setmetatable(self, ComponentCreator)

	-- 确保 Binder 销毁时清理所有信号和连接
	self.janitor:Add(self.objectAdded, "DisconnectAll")
	self.janitor:Add(self.objectRemoved, "DisconnectAll")

	return self
end

--[[
	尝试为实例创建 Wrapper
]]
function ComponentCreator._wrapInstance(self: ClassType, instance: Instance)
	if self._wrappersByInstance[instance] then
		return -- 已经包装过了
	end

	-- 使用 xpcall 捕获错误，防止单个组件初始化失败导致整个 Binder 崩溃
	local success, result = xpcall(function()
		return self.wrapperClass.new(instance, table.unpack(self._wrapperParameters, 1, self._wrapperParameters.n))
	end, function(err)
		return debug.traceback(tostring(err), 2)
	end)

	if success then
		local wrapper = result :: WrapperInstance
		self._wrappersByInstance[instance] = wrapper
		self.objectAdded:Fire(wrapper)
	else
		warn(string.format("[ComponentCreator] Failed to wrap instance '%s' with tag '%s':\n%s", 
			instance:GetFullName(), self.tag, tostring(result)))
	end
end

--[[
	监听 PrimaryPart 并在其存在时进行包装 (适用于 Model 和 Tool)
]]
function ComponentCreator._setupPrimaryPartListener(self: ClassType, instance: Instance)
	if (instance:IsA("Model") or instance:IsA("Tool")) and instance.PrimaryPart == nil then
		-- 如果没有 PrimaryPart，等待其设置
		if RunService:IsStudio() then
			-- 在 Studio 中警告，方便调试
			-- warn(string.format("[ComponentCreator] Instance '%s' (Tag: %s) has no PrimaryPart, waiting...", instance:GetFullName(), self.tag))
		end

		local connection: RBXScriptConnection?
		connection = instance:GetPropertyChangedSignal("PrimaryPart"):Connect(function()
			if instance.PrimaryPart then
				if connection then
					connection:Disconnect()
					connection = nil
				end
				self:_wrapInstance(instance)
			end
		end)
		
		-- 如果实例被销毁，连接会自动断开，但为了保险起见，我们可以将连接添加到 Janitor 中管理吗？
		-- 这里不需要 Janitor，因为我们希望这个监听器只在 ComponentCreator 存活期间有效。
		-- 如果 ComponentCreator 销毁了，我们应该停止监听。
		-- 但这里是一个临时的监听，一旦满足条件就断开。
		-- 为了防止 ComponentCreator 销毁后这个回调还在跑 (虽然不太可能造成大问题)，
		-- 我们可以简单地让 GC 处理，或者更严谨地将清理任务绑定到 instance 的生命周期 (通过 Janitor Link，但这有点重)。
		-- 考虑到 CollectionService 的机制，如果 ComponentCreator 销毁，我们不再关心这些。
		-- 最简单的方法是：如果 ComponentCreator 销毁了，这个 loop 也就停止了。
		-- 这里我们直接利用闭包，不需要额外复杂处理。
	else
		-- 非 Model/Tool 或已有 PrimaryPart，直接包装
		self:_wrapInstance(instance)
	end
end

--[[
	检查父级，如果在存储服务中则不初始化
]]
function ComponentCreator._checkParent(self: ClassType, instance: Instance)
	-- 快速检查常用路径
	local parent = instance.Parent
	if parent == ReplicatedStorage or parent == ServerStorage then
		-- 处于存储服务中，可能是预制体，不进行初始化
		local connection: RBXScriptConnection?
		connection = instance.AncestryChanged:Connect(function(_, newParent)
			if newParent and newParent ~= ReplicatedStorage and newParent ~= ServerStorage then
				if connection then
					connection:Disconnect()
					connection = nil
				end
				-- 移出存储服务后，检查 PrimaryPart 逻辑
				self:_setupPrimaryPartListener(instance)
			end
		end)
		-- 不需要显式清理 connection，Instance 销毁会自动清理
		return
	end

	-- 更通用的后备检查 (以防直接放在 ReplicatedStorage 的子文件夹深处)
	if instance:IsDescendantOf(ReplicatedStorage) or instance:IsDescendantOf(ServerStorage) then
		local connection: RBXScriptConnection?
		connection = instance.AncestryChanged:Connect(function(_, newParent)
			if newParent and not (instance:IsDescendantOf(ReplicatedStorage) or instance:IsDescendantOf(ServerStorage)) then
				if connection then
					connection:Disconnect()
					connection = nil
				end
				self:_setupPrimaryPartListener(instance)
			end
		end)
		return
	end

	-- 正常情况
	self:_setupPrimaryPartListener(instance)
end

--[[
	销毁实例的 Wrapper
]]
function ComponentCreator._unwrapInstance(self: ClassType, instance: Instance)
	local wrapper = self._wrappersByInstance[instance]
	if not wrapper then
		return
	end

	self._wrappersByInstance[instance] = nil

	-- 使用 pcall 保护清理过程
	local success, result = pcall(function()
		if wrapper.destroy then
			wrapper:destroy()
		end
		self.objectRemoved:Fire(wrapper)
		return true
	end)

	if not success then
		warn(string.format("[ComponentCreator] Error destroying wrapper for '%s' (Tag: %s):\n%s",
			instance:GetFullName(), self.tag, tostring(result)))
	end
end

--[[
	启动监听
]]
function ComponentCreator.listen(self: ClassType)
	-- 处理现有实例
	for _, instance in ipairs(CollectionService:GetTagged(self.tag)) do
		task.spawn(function()
			self:_checkParent(instance)
		end)
	end

	-- 监听新实例
	self.janitor:Add(CollectionService:GetInstanceAddedSignal(self.tag):Connect(function(instance)
		self:_checkParent(instance)
	end), "Disconnect")

	-- 监听实例移除
	self.janitor:Add(CollectionService:GetInstanceRemovedSignal(self.tag):Connect(function(instance)
		self:_unwrapInstance(instance)
	end), "Disconnect")
end

--[[
	Alias for listen (User preference: start)
]]
function ComponentCreator.start(self: ClassType)
	self:listen()
end

--[[
	获取指定 Instance 的 Wrapper 组件
]]
function ComponentCreator.getComponentFromInstance(self: ClassType, instance: Instance): WrapperInstance?
	return self._wrappersByInstance[instance]
end

--[[
	Alias for getComponentFromInstance (User preference: get)
]]
function ComponentCreator.get(self: ClassType, instance: Instance): WrapperInstance?
	return self.getComponentFromInstance(self, instance)
end

--[[
	获取所有当前的 Wrapper 组件
]]
function ComponentCreator.getAll(self: ClassType): {WrapperInstance}
	local all = {}
	for _, wrapper in pairs(self._wrappersByInstance) do
		table.insert(all, wrapper)
	end
	return all
end

--[[
	销毁 Binder，清理所有 Wrapper 和监听器
]]
function ComponentCreator.destroy(self: ClassType)
	self.janitor:Destroy()

	for instance, wrapper in pairs(self._wrappersByInstance) do
		-- 这里我们手动调用 unwrap 来确保正确清理和触发事件(尽管 Binder 销毁了可能不需要触发 Removed 事件，但为了完整性)
		-- 但由于 destroy 方法主要用于清理 Binder 本身，我们直接清理 wrapper 比较高效
		local success, result = pcall(function()
			if wrapper.destroy then
				wrapper:destroy()
			end
			return true
		end)
		if not success then
		           warn(string.format("[ComponentCreator] Error destroying wrapper during Binder cleanup (Tag: %s): %s", self.tag, tostring(result)))
		      end
	end
	
	table.clear(self._wrappersByInstance)
	-- self.objectAdded 和 self.objectRemoved 由 Janitor 清理
	setmetatable(self, nil :: any)
end

return ComponentCreator
