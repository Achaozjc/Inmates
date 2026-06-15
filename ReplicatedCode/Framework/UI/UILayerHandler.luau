--!nonstrict
-- 原因：layerClassInstance 使用 any 类型接收外部 GUI 实例，UILayerId/UILayerType 为字符串枚举模拟，
-- strict 模式下大量索引操作会产生误报，后续可在枚举类型完善后切回 strict。
--[[
    模块：UILayerHandler
    描述：管理游戏内 UI 层级的显示与隐藏，处理菜单堆栈、HUD 互斥及模糊背景效果。
    
    核心机制：
    1. 菜单 (Menu) 使用栈结构管理 (`_menuQueue`)，同一时间通常只显示一个菜单（栈顶）。
    2. HUD (HeadsUpDisplay) 可以共存，但通常在菜单打开时自动隐藏，除非配置了白名单 (`stayVisibleWith`)。
    3. 视觉效果：根据当前激活的菜单自动处理背景模糊 (Blur) 和手柄光标 (Gamepad Cursor)。

    优化记录：
    - 修复了 Blur/Cursor 控制逻辑，使其依赖于“当前激活的菜单”而非“触发更新的层”。
    - 引入 TweenService 实现 Blur 的平滑过渡。
    - 修正了 HUD 无法单独隐藏的逻辑缺陷。
    - 增强了类型安全和代码注释。
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local GamepadService = game:GetService("GamepadService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")

-- 模块依赖
local Signal = require(ReplicatedStorage.ReplicatedCode.Framework.Packages.Signal)
local UILayerType = require(ReplicatedStorage.ReplicatedCode.Framework.UI.UILayerType)
local UILayerId = require(ReplicatedStorage.ReplicatedCode.Framework.UI.UILayerId)
local InputCategorizer = require(ReplicatedStorage.ReplicatedCode.Framework.Input.InputCategorizer)
local InputCategory = require(ReplicatedStorage.ReplicatedCode.Framework.Input.InputCategory)
local getCodeAsset = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Instance.GetCodeAsset)

-- 类型定义
export type LayerDataType = {
	isVisible: boolean, -- 当前计算出的可见性状态
	layerType: UILayerType.EnumType, -- 层级类型：Menu 或 HUD
	layerClassInstance: any, -- 对应的 UI 类实例
	visibilityChangedSignal: Signal.ClassType, -- 可见性变更信号
	stayVisibleWith: { [string]: boolean }?, -- 白名单：当这些 Menu 打开时，此 HUD 保持显示
	showGamepad: boolean, -- 是否启用手柄光标
	showBlur: boolean, -- 是否启用模糊背景
}

local UILayerHandler = {}

-- 私有状态
UILayerHandler._menuQueue = {} :: { UILayerId.EnumType } -- 菜单栈：栈顶元素为当前激活的菜单
UILayerHandler._hudLayersEnabledByLayerId = {} :: { [UILayerId.EnumType]: boolean } -- 记录哪些 HUD 被业务逻辑请求显示
UILayerHandler._layerDataById = {} :: { [any]: LayerDataType } -- 所有注册层的数据
UILayerHandler._lastAreMenusVisible = false -- 缓存上一次菜单是否可见的状态，用于去重信号
UILayerHandler.areMenusVisibleChanged = Signal.new() :: Signal.ClassType -- 全局菜单状态变更信号
UILayerHandler._gamepadCursorTarget = nil :: GuiObject? -- 手柄光标优先目标（如教程高亮按钮）
UILayerHandler._forceGamepadCursor = false -- 是否强制显示手柄光标（用于非菜单弹层）
UILayerHandler._gamepadVirtualCursorDisabled = false -- 是否禁用虚拟光标渲染（仅使用 SelectedObject 硬焦点）
UILayerHandler._lastGamepadCursorEnabled = false -- 缓存手柄光标开启状态
UILayerHandler._lastGamepadCursorActualTarget = nil :: GuiObject? -- 缓存手柄光标实际设置的目标

-- 常量配置
local BLUR_SIZE = 10 -- 模糊强度目标值
local TWEEN_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) -- 模糊过渡动画配置

-- 模糊效果初始化
local camera = Workspace.CurrentCamera
local prefabFolder: Instance = getCodeAsset("UI", "UILayerHandler")
local blurInstance = prefabFolder:WaitForChild("MenuBlurPrefab"):Clone() :: BlurEffect
-- 预制体默认 Size=24 且 Enabled=true，若不重置会在无菜单时也保持全屏模糊
blurInstance.Size = 0
blurInstance.Enabled = false
blurInstance.Parent = camera

local currentBlurTween: Tween? = nil

local function _resolveGamepadCursorTarget(): GuiObject?
	local target = UILayerHandler._gamepadCursorTarget
	if not target then
		return nil
	end
	-- 目标已销毁或不可见:顺带清掉缓存引用,避免下次还拿到 stale Instance
	if not target.Parent or not target.Visible then
		UILayerHandler._gamepadCursorTarget = nil
		UILayerHandler._forceGamepadCursor = false
		return nil
	end

	local absSize = target.AbsoluteSize
	if absSize.X <= 0 or absSize.Y <= 0 then
		return nil
	end

	return target
end

local function _isTargetInViewport(target: GuiObject): boolean
	local camera = Workspace.CurrentCamera
	if not camera then
		return false
	end
	local vp = camera.ViewportSize
	local absPos = target.AbsolutePosition
	local absSize = target.AbsoluteSize
	
	local left = absPos.X
	local top = absPos.Y
	local right = left + absSize.X
	local bottom = top + absSize.Y
	
	if right <= 0 or bottom <= 0 or left >= vp.X or top >= vp.Y then
		return false
	end
	
	return true
end

-- 调试输出：打印当前已注册的所有 UI 层（仅 Studio）
local function _debugPrintRegisteredLayers()
	if not RunService:IsStudio() then
		return
	end

	local layerIds = {}
	for layerId in pairs(UILayerHandler._layerDataById) do
		table.insert(layerIds, tostring(layerId))
	end
	table.sort(layerIds)

	print(string.format("[UILayerHandler] 已注册层数量: %d", #layerIds))
	for index, layerId in ipairs(layerIds) do
		print(string.format("[UILayerHandler] %02d. %s", index, layerId))
	end
end

--[=[
    注册一个新的 UI 层级。
    @param layerId 层的唯一标识符 (UILayerId)
    @param layerType 层的类型 (Menu 或 HUD)
    @param layerClassInstance UI 类的实例
    @param stayVisibleWithMenus (可选) 一个菜单 ID 列表，当这些菜单打开时，此 HUD 不会被自动隐藏
    @param showGamepad (可选) 是否启用沉浸模式（模糊背景 + 手柄光标控制）。默认为 true。
    @return Signal.ClassType 返回一个信号，当层级可见性改变时触发，UI 类应监听此信号来显示/隐藏自己
]=]
function UILayerHandler.registerLayer(
	layerId: UILayerId.EnumType,
	layerType: UILayerType.EnumType,
	layerClassInstance: any,
	stayVisibleWithMenus: { string }?,
	showGamepad: boolean?,
	showBlur: boolean?
): Signal.ClassType
	assert(not UILayerHandler._layerDataById[layerId], string.format("LayerId %s 已经被注册过了", tostring(layerId)))

	-- 转换数组为哈希表以优化查找性能 (O(1))
	local stayVisibleWith = {}
	if stayVisibleWithMenus then
		for _, menuId in ipairs(stayVisibleWithMenus) do
			stayVisibleWith[menuId] = true
		end
	end
	
	-- 处理 showGamepad 默认值逻辑：如果未提供或为 true，则启用；如果显式为 false，则禁用。
	local shouldShowGamepad = true
	if showGamepad ~= nil then
		shouldShowGamepad = showGamepad
	end
	
	-- 处理 showBlur 默认值逻辑
	local shouldShowBlur = true
	if showBlur ~= nil then
		shouldShowBlur = showBlur
	elseif showGamepad ~= nil then
		-- 向后兼容：如果未提供 showBlur 但提供了 showGamepad，则 showBlur 默认与 showGamepad 相同
		shouldShowBlur = showGamepad
	end

	UILayerHandler._layerDataById[layerId] = {
		isVisible = false,
		layerType = layerType,
		layerClassInstance = layerClassInstance,
		visibilityChangedSignal = Signal.new(),
		stayVisibleWith = stayVisibleWith, 
		showGamepad = shouldShowGamepad,
		showBlur = shouldShowBlur
	} :: LayerDataType

	--_debugPrintRegisteredLayers()
	
	return UILayerHandler._layerDataById[layerId].visibilityChangedSignal
end

--[=[
    内部函数：更新模糊效果和手柄光标状态。
    基于“当前栈顶菜单”的配置来决定是否启用效果。
    使用 TweenService 实现模糊的平滑淡入淡出。
    @param shouldShow 是否应该显示效果
]=]
function UILayerHandler._updateEffects(shouldShowBlur: boolean, shouldShowGamepad: boolean)
	-- 1. 处理 Blur 的平滑过渡
	-- 如果之前的动画还在播放，先取消，避免冲突
	if currentBlurTween then
		currentBlurTween:Cancel()
		currentBlurTween = nil
	end

	local targetSize = shouldShowBlur and BLUR_SIZE or 0
	
	-- 性能优化：只有目标值不同才创建 Tween，避免重复调用
	if blurInstance.Size ~= targetSize then
		if shouldShowBlur then
			blurInstance.Enabled = true -- 开始变大前先启用
		end
		
		currentBlurTween = TweenService:Create(blurInstance, TWEEN_INFO, { Size = targetSize })
		if currentBlurTween then
			currentBlurTween:Play()
		end

		-- 如果是关闭效果，等待动画完成后再禁用 Enabled，节省渲染开销
		if not shouldShowBlur then
			task.spawn(function()
				local myTween = currentBlurTween
				if myTween then
					myTween.Completed:Wait()
					-- 双重检查：确保在等待期间没有新的 Tween 启动改变了意图
					if blurInstance.Size == 0 and currentBlurTween == myTween then
						blurInstance.Enabled = false
					end
				end
			end)
		end
	end

	-- 2. 处理 Gamepad 光标
	-- 仅当当前输入设备是 Gamepad 时才干预
	if InputCategorizer.getLast() == InputCategory.Gamepad then
		local target = _resolveGamepadCursorTarget()
		
		-- 检查是否在视口内，避免引擎警告
		local function tryEnable()
			local function doEnable()
				if target.Selectable then
					pcall(function() GuiService.SelectedObject = target end)
				end

				if UILayerHandler._gamepadVirtualCursorDisabled then
					if UILayerHandler._lastGamepadCursorEnabled ~= false then
						UILayerHandler._lastGamepadCursorEnabled = false
						UILayerHandler._lastGamepadCursorActualTarget = nil
						pcall(function() GamepadService:DisableGamepadCursor() end)
					end
				else
					if UILayerHandler._lastGamepadCursorEnabled ~= true or UILayerHandler._lastGamepadCursorActualTarget ~= target then
						UILayerHandler._lastGamepadCursorEnabled = true
						UILayerHandler._lastGamepadCursorActualTarget = target
						pcall(function()
							GamepadService:EnableGamepadCursor(target)
						end)
					end
				end
			end

			if _isTargetInViewport(target) then
				doEnable()
			else
				task.spawn(function()
					RunService.Heartbeat:Wait()
					if target == UILayerHandler._gamepadCursorTarget and target.Parent and target.Visible and _isTargetInViewport(target) then
						doEnable()
					end
				end)
			end
		end

		if shouldShowGamepad or UILayerHandler._forceGamepadCursor then
			if target then
				tryEnable()
			else
				if UILayerHandler._lastGamepadCursorEnabled ~= true or UILayerHandler._lastGamepadCursorActualTarget ~= nil then
					UILayerHandler._lastGamepadCursorEnabled = true
					UILayerHandler._lastGamepadCursorActualTarget = nil
					pcall(function() GamepadService:EnableGamepadCursor(nil) end)
				end
			end
		else
			if UILayerHandler._lastGamepadCursorEnabled ~= false then
				UILayerHandler._lastGamepadCursorEnabled = false
				UILayerHandler._lastGamepadCursorActualTarget = nil
				pcall(function() GamepadService:DisableGamepadCursor() end)
			end
			GuiService.SelectedObject = nil
		end
	end
end

--[=[
	设置手柄光标的优先定位目标。
	当菜单处于可显示手柄光标状态时，会立即刷新到新目标。
	@param target 目标 GUI，传 nil 表示清空目标
	@param forceCursor true 时在非菜单场景也强制启用手柄光标
]=]
function UILayerHandler.setGamepadCursorTarget(target: GuiObject?, forceCursor: boolean?, forceBlur: boolean?, disableVirtualCursor: boolean?)
	UILayerHandler._gamepadCursorTarget = target
	UILayerHandler._forceGamepadCursor = (forceCursor == true) and (target ~= nil)
	UILayerHandler._gamepadVirtualCursorDisabled = (disableVirtualCursor == true)

	-- 若要求强制启用，则直接刷新（用于非菜单弹层）
	if UILayerHandler._forceGamepadCursor then
		local shouldBlur = if forceBlur ~= nil then forceBlur else (UILayerHandler._menuQueue[1] ~= nil)
		UILayerHandler._updateEffects(shouldBlur, true)
		return
	end

	-- 否则仅在有菜单激活且当前菜单允许手柄光标时立即生效
	local currentMenuId = UILayerHandler._menuQueue[1] :: string
	if not currentMenuId then
		UILayerHandler._updateEffects(false, false)
		return
	end
	local topMenuData = UILayerHandler._layerDataById[currentMenuId]
	if not topMenuData then
		UILayerHandler._updateEffects(false, false)
		return
	end

	UILayerHandler._updateEffects(topMenuData.showBlur, topMenuData.showGamepad)
end

--[=[
    内部函数：核心刷新逻辑。
    重新计算所有层的可见性，并处理全局状态（如 Blur）。
    该函数在任何层显示/隐藏状态改变时调用。
]=]
function UILayerHandler._updateAllLayers()
	local currentMenuId = UILayerHandler._menuQueue[1] ::string
	local areMenusVisible = currentMenuId ~= nil
	
	-- 步骤 1: 确定全局效果状态 (Blur / Gamepad)
	-- 逻辑修复：不再依赖触发更新的 layerId，而是完全取决于当前栈顶菜单的配置
	local shouldShowBlur = false
	local shouldShowGamepad = false
	if currentMenuId then
		local topMenuData = UILayerHandler._layerDataById[currentMenuId]
		if topMenuData then
			shouldShowGamepad = topMenuData.showGamepad
			shouldShowBlur = topMenuData.showBlur
		end
	end
	
	UILayerHandler._updateEffects(shouldShowBlur, shouldShowGamepad)

	-- 步骤 2: 遍历所有层并计算可见性
	for layerId , layerData in pairs(UILayerHandler._layerDataById) do
		local isLayerVisible = false
		
		if layerData.layerType == UILayerType.HeadsUpDisplay then
			-- HUD 显示规则：
			-- 1. 必须先被显式启用 (showHud 调用过)
			if UILayerHandler._hudLayersEnabledByLayerId[layerId] then
				-- 2. 如果没有菜单显示，或者该 HUD 在当前菜单的白名单中，则显示
				if not areMenusVisible then
					isLayerVisible = true
				elseif currentMenuId and layerData.stayVisibleWith and layerData.stayVisibleWith[currentMenuId] then
					isLayerVisible = true
				end
			end
			
		elseif layerData.layerType == UILayerType.Menu then			
			-- Menu 显示规则：只有栈顶菜单可见
			isLayerVisible = (currentMenuId == layerId)
		end
		
		UILayerHandler._updateLayerVisibility(layerId, isLayerVisible)
	end
	
	-- 步骤 3: 触发全局菜单状态变更信号
	if areMenusVisible ~= UILayerHandler._lastAreMenusVisible then
		UILayerHandler._lastAreMenusVisible = areMenusVisible	
		UILayerHandler.areMenusVisibleChanged:Fire(areMenusVisible)
	end
end

--[=[
    内部函数：更新单个层的可见性并触发信号。
    @param layerId 层ID
    @param isVisible 目标可见性
]=]
function UILayerHandler._updateLayerVisibility(layerId: UILayerId.EnumType, isVisible: boolean)
	local data = UILayerHandler._layerDataById[layerId]
	if not data then return end

	-- 性能优化：状态未变时不触发信号
	if isVisible == data.isVisible then	
		return
	end
	data.isVisible = isVisible
	data.visibilityChangedSignal:Fire(isVisible)
end

--[=[
    显示指定的层。
    如果是 Menu，会加入菜单栈顶。
    如果是 HUD，会标记为启用。
    @param layerId UILayerId
]=]
function UILayerHandler.show(layerId: UILayerId.EnumType)
	local layerData = UILayerHandler._layerDataById[layerId]
	if not layerData then
		warn(string.format("尝试显示未注册的层: %s", tostring(layerId)))
		return
	end
	
	if layerData.layerType == UILayerType.Menu then
		-- 菜单逻辑：入栈
		-- 如果已经在栈中，先移除（避免重复），再放到栈顶
		local existingIndex = table.find(UILayerHandler._menuQueue, layerId)
		if existingIndex then
			table.remove(UILayerHandler._menuQueue, existingIndex)
		end
		table.insert(UILayerHandler._menuQueue, 1, layerId)
		
	elseif layerData.layerType == UILayerType.HeadsUpDisplay then
		-- HUD 逻辑：标记为启用
		UILayerHandler._hudLayersEnabledByLayerId[layerId] = true
	end
	
	UILayerHandler._updateAllLayers()
end

--[=[
    隐藏指定的层。
    如果是 Menu，从栈中移除。
    如果是 HUD，标记为禁用。
    @param layerId UILayerId
]=]
function UILayerHandler.hide(layerId: UILayerId.EnumType)
	local layerData = UILayerHandler._layerDataById[layerId]
	if not layerData then
		return
	end
	
	if layerData.layerType == UILayerType.Menu then
		-- 菜单逻辑：出栈
		local index = table.find(UILayerHandler._menuQueue, layerId)
		if index then
			table.remove(UILayerHandler._menuQueue, index)
			UILayerHandler._updateAllLayers() -- 只有真的移除才更新，避免不必要的计算
		end
		
	elseif layerData.layerType == UILayerType.HeadsUpDisplay then
		-- HUD 逻辑：标记为禁用
		-- 只有当状态真的改变时才刷新
		if UILayerHandler._hudLayersEnabledByLayerId[layerId] then
			UILayerHandler._hudLayersEnabledByLayerId[layerId] = nil
			UILayerHandler._updateAllLayers()
		end
	end
end

--[=[
    查询层当前是否可见。
    @param layerId UILayerId
    @return boolean
]=]
function UILayerHandler.isVisible(layerId: UILayerId.EnumType): boolean
	local data = UILayerHandler._layerDataById[layerId]
	assert(data, string.format("Layer %s 未注册", tostring(layerId)))
	return data.isVisible
end

--[=[
    获取层关联的 UI 实例。
    @param layerId UILayerId
    @return any
]=]
function UILayerHandler.getLayerClassInstanceById(layerId: UILayerId.EnumType): any
	local data = UILayerHandler._layerDataById[layerId]
	assert(data, string.format("Layer %s 未注册", tostring(layerId)))
	return data.layerClassInstance
end

-- 订阅已注册层的可见性变化（用于跨 GUI 联动，如关闭某菜单后刷新 HUD 红点）
function UILayerHandler.connectVisibilityChanged(
	layerId: UILayerId.EnumType,
	callback: (isVisible: boolean) -> ()
): RBXScriptConnection?
	local data = UILayerHandler._layerDataById[layerId]
	if not data then
		return nil
	end
	return data.visibilityChangedSignal:Connect(callback)
end

InputCategorizer.changed:Connect(function(newCategory)
	if newCategory == InputCategory.Gamepad then
		UILayerHandler._updateAllLayers()
	else
		if UILayerHandler._lastGamepadCursorEnabled ~= false then
			UILayerHandler._lastGamepadCursorEnabled = false
			UILayerHandler._lastGamepadCursorActualTarget = nil
			GamepadService:DisableGamepadCursor()
		end
		GuiService.SelectedObject = nil
	end
end)

return UILayerHandler
