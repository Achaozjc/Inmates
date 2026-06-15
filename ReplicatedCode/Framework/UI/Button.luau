--!strict

--[[
	An object with hover / pressed / selected and activated listeners

	- Hover: A state of 'hovering' when a physical or virtual mouse cursor is over the button
	- Press: A state of 'depression' when the button is being actively engaged by a mouse click, gamepad press, or finger touch
	- Selected: A state of 'engagement' where the button is currently being selected in gamepad navigation
	- Activated: A discrete activation of the button, via mouse click, gamepad press or finger touch (distinct from press, which is a state that begins and ends)

	Takes optional keycodes to bind to the activated event for ease of use creating keyboard shortcuts and gamepad input compatibility
	- 悬停： 当物理或虚拟鼠标光标位于按钮上方时的 "悬停 "状态
	- 按下 按下： 当鼠标点击、游戏手柄按下或手指触摸时，按钮处于 "按下 "状态。
	- 选中： 啮合 "状态，此时按钮正在游戏手柄导航中被选中
	- 激活： 通过鼠标点击、游戏手柄按压或手指触摸激活按钮（有别于按压，按压是一种开始和结束的状态）

	可选择将按键代码绑定到激活事件，以方便创建键盘快捷键和兼容游戏手柄输入
--]]

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local InputCategory = require(ReplicatedStorage.ReplicatedCode.Framework.Input.InputCategory)
local InputCategorizer = require(ReplicatedStorage.ReplicatedCode.Framework.Input.InputCategorizer)
local Signal = require(ReplicatedStorage.ReplicatedCode.Framework.Packages.Signal)
local Connections = require(ReplicatedStorage.ReplicatedCode.Framework.Infrastructure.Classes.Connections)
local getInstance = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Instance.GetInstance)
local getCodeAsset = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Instance.GetCodeAsset)

local prefabFolder: Folder = getCodeAsset("UI", "Button")
local prefabInstance: GuiButton = (getInstance(prefabFolder, "ButtonPrefab") :: any) :: GuiButton
local buttonSoundEffect = (getInstance(SoundService, "SFX", "Button") :: any) :: AudioPlayer
local hoverSoundEffect = (getInstance(SoundService, "SFX", "Hover") :: any) :: AudioPlayer
local GamepadButtonPrompt = require(ReplicatedStorage.ReplicatedCode.Framework.Input.GamepadButtonPrompt)

export type KeyCodeBindingInfo = {
	actionName: string,
	keyCodes: { Enum.KeyCode }?,  -- KeyCode如果 gameProcessedEvent 为 true，则不处理此列表中的关键代码
	alwaysProcessedKeyCodes: { Enum.KeyCode }?, -- KeyCodes 即使 gameProcessedEvent 为 true，该列表中的按键代码也始终会被处理
}

local Button = {}
Button.__index = Button

export type ClassType = typeof(setmetatable(
	{} :: {
		_instance: GuiButton,
		_connections: Connections.ClassType,
		_hovering: boolean,
		_pressing: boolean,
		_selecting: boolean,
		_isEnabled: boolean,
		_keyCodeBindingInfo: KeyCodeBindingInfo?,
		_gamepadCode: Enum.KeyCode?,
		_gamepadButtonPrompt: GamepadButtonPrompt.ClassType?,
		hovered: Signal.ClassType,
		selected: Signal.ClassType,
		pressed: Signal.ClassType,
		activated: Signal.ClassType,
	},
	Button
))

function Button.new(button:GuiButton?, keyCodeBindingInfo: KeyCodeBindingInfo?, gamepadCode :Enum.KeyCode?): ClassType
	local self = setmetatable({
		_instance = button or prefabInstance:Clone(),
		_connections = Connections.new(),
		_hovering = false,
		_pressing = false,
		_selecting = false,
		_isEnabled = false,
		_keyCodeBindingInfo = keyCodeBindingInfo,
		_gamepadCode = gamepadCode,
		_gamepadButtonPrompt = nil,
		hovered = Signal.new(),
		selected = Signal.new(),
		pressed = Signal.new(),
		activated = Signal.new(),
	}, Button) :: ClassType
	
	if self._gamepadCode then
		self._gamepadButtonPrompt = GamepadButtonPrompt.new(self._gamepadCode)
		self._gamepadButtonPrompt:setParent(self._instance)	
	end
	
	
	self:setEnabled(true)

	return self
end

function Button.setParent(self: ClassType, parent: Instance)
	self._instance.Parent = parent
end

function Button.setVisible(self: ClassType, visible: boolean)
	self._instance.Visible = visible
end

function Button.isHovering(self: ClassType)
	return self._hovering
end

function Button.isPressed(self: ClassType)
	return self._pressing
end

function Button.isSelected(self: ClassType)
	return self._selecting
end

function Button.getInstance(self: ClassType)
	return self._instance
end

function Button.setEnabled(self: ClassType, isEnabled: boolean)
	if isEnabled then
		self:_enableInput()
	else
		self:_disableInput()
	end
	self:_connectGamepadButtonPrompt(isEnabled)
	self._isEnabled = isEnabled
end

function Button.setSelectable(self: ClassType, isSelectable: boolean)
	self._instance.Selectable = isSelectable
end

function Button.isEnabled(self: ClassType)
	return self._isEnabled
end

function Button._onHover(self: ClassType, isHovering: boolean)
	self._hovering = isHovering

	self.hovered:Fire(isHovering, self._instance)
end

function Button._onPress(self: ClassType, isPressing: boolean, screenPosition: Vector2?)
	self._pressing = isPressing

	self.pressed:Fire(isPressing, self._instance, screenPosition)
end

function Button._onSelected(self: ClassType, isSelected: boolean)
	self._selecting = isSelected

	self.selected:Fire(isSelected, self._instance)
end

function Button._onActivated(self: ClassType)
	if not self:isEnabled() then
		return
	end

	buttonSoundEffect:Play()

	self.activated:Fire(self._instance)
end
function Button._enableInput(self: ClassType)
	-- 如果 setEnabled 被多次调用为 true，则防止重复连接
	if self._isEnabled then
		return
	end

	self:_listenForHover()
	self:_listenForSelected()
	self:_listenForPress()
	self:_listenForActivation()
	self:_connectInputBindings()
	
end

--function Button._listenForInput(self: ClassType)
--	local mouseEnterConnection = self._instance.InputBegan:Connect(function()
--		self:_onHover(true)
--	end)

--	local mouseLeaveConnection = self._instance.InputEnded:Connect(function()
--		self:_onHover(false)
--	end)

--	self._connections:add(mouseEnterConnection, mouseLeaveConnection)
--end


function Button._disableInput(self: ClassType)
	self._connections:disconnect()

end



function Button._listenForHover(self: ClassType)
	local mouseEnterConnection = self._instance.MouseEnter:Connect(function()
		self:_onHover(true)
	end)

	local mouseLeaveConnection = self._instance.MouseLeave:Connect(function()
		self:_onHover(false)
	end)

	self._connections:add(mouseEnterConnection, mouseLeaveConnection)
end

function Button._listenForSelected(self: ClassType)
	local selectionGainedConnection = self._instance.SelectionGained:Connect(function()
		self:_onSelected(true)
	end)
	local selectionLostConnection = self._instance.SelectionLost:Connect(function()
		self:_onSelected(false)
	end)

	self._connections:add(selectionGainedConnection, selectionLostConnection)
end

function Button._listenForPress(self: ClassType)
	-- 尽管命名为 GuiButton.MouseButton1Down，但它会在鼠标、触控和游戏手柄交互时启动
	local buttonDownConnection = self._instance.MouseButton1Down:Connect(function(x: number, y: number)
		self:_onPress(true, Vector2.new(x, y))
	end)

	local buttonUpConnection = self._instance.MouseButton1Up:Connect(function(x: number, y: number)
		self:_onPress(false, Vector2.new(x, y))
	end)
	

	
	self._connections:add(buttonDownConnection, buttonUpConnection)
end

function Button._listenForActivation(self: ClassType)
	local activatedConnection = self._instance.Activated:Connect(function()
		self:_onActivated()

	end)

	self._connections:add(activatedConnection)
end

function Button._connectGamepadButtonPrompt(self: ClassType, isEnabled: boolean)
	if not self._gamepadButtonPrompt then
		return
	end
	self._gamepadButtonPrompt:setEnabled(isEnabled)
end



function Button._connectInputBindings(self: ClassType)
	if not self._keyCodeBindingInfo then
		return
	end
	local keyCodeBindingInfo = self._keyCodeBindingInfo :: KeyCodeBindingInfo

	-- 如果我们想监听激活按钮（如 ButtonA），就不能使用 ContextActionService，因为
	-- 在 "选择 "模式下，按下 ButtonA 会被视为 gameProcessedEvents。ContextActionService 会忽略
	-- 任何 gameProcessedEvents，而使用 UserInputService，我们仍可监听这些事件。
	local inputConnection = UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
		local inputCategory = InputCategorizer.getCategoryOf()
		if inputCategory ~= InputCategory.Gamepad and inputCategory ~= InputCategory.KeyboardAndMouse then
			return
		end
		local alwaysProcess = table.find(keyCodeBindingInfo.alwaysProcessedKeyCodes or {}, input.KeyCode)
		if gameProcessedEvent and not alwaysProcess then
			return
		end
		if alwaysProcess or table.find(keyCodeBindingInfo.keyCodes or {}, input.KeyCode) then
			self:_onActivated()	
		
		end
	end)

	self._connections:add(inputConnection)
end

function Button.destroy(self: ClassType)
	self.hovered:DisconnectAll()
	self.pressed:DisconnectAll()
	self.activated:DisconnectAll()
	self.selected:DisconnectAll()

	self:_disableInput()
	if self._gamepadButtonPrompt then
		self._gamepadButtonPrompt:destroy()
	end

end

return Button

