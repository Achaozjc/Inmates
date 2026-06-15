--!strict

--[[
	Button icon hint to show the player what gamepad button to press.
	Automatically becomes visible during gamepad input, and hides itself on non-gamepad input.
	TODO: Animate icon on pressed?
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local InputCategorizer = require(ReplicatedStorage.ReplicatedCode.Framework.Input.InputCategorizer)
local InputCategory = require(ReplicatedStorage.ReplicatedCode.Framework.Input.InputCategory)
local Signal = require(ReplicatedStorage.ReplicatedCode.Framework.Packages.Signal)
--local formatImageForKeyCode = require(ReplicatedStorage.ReplicatedCode.Framework.Input.FormatImageForKeyCode)
local getInstance = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Instance.GetInstance)
local getCodeAsset = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Instance.GetCodeAsset)
local InputMetadata = require(ReplicatedStorage.ReplicatedCode.Framework.Input.InputMetadata)

local prefabFolder: Folder = getCodeAsset("Input", "ButtonPrompt")
local prefabInstance: Frame = (getInstance(prefabFolder, "ButtonDisplayFrame") :: any) :: Frame

export type KeyCodeBindingInfo = {
	actionName: string,
	keyCodes: { Enum.KeyCode }?, -- KeyCode如果 gameProcessedEvent 为 true，则不处理此列表中的关键代码
	alwaysProcessedKeyCodes: { Enum.KeyCode }?, -- KeyCodes 即使 gameProcessedEvent 为 true，该列表中的按键代码也始终会被处理
}

local ButtonPrompt = {}
ButtonPrompt.__index = ButtonPrompt

export type ClassType = typeof(setmetatable(
	{} :: {
		_instance: Frame,

		_isEnabled: boolean,
		_shouldBeVisible: boolean,
		_keyboardAndMouseInput: Enum.KeyCode | Enum.UserInputType,
		_gamepadInput: Enum.KeyCode | Enum.UserInputType,
		_inputTypeChangedConnection: Signal.SignalConnection?,
	},
	ButtonPrompt
))

function ButtonPrompt.new(
	keyboardAndMouseInput: Enum.KeyCode | Enum.UserInputType,
	gamepadInput: Enum.KeyCode | Enum.UserInputType
): ClassType
	local self = {
		_instance = prefabInstance:Clone() :: Frame,
		_keyboardAndMouseInput = keyboardAndMouseInput,
		_gamepadInput = gamepadInput,
		_isEnabled = true,
		_shouldBeVisible = false,
		_inputTypeChangedConnection = nil :: Signal.SignalConnection?,
	}
	setmetatable(self, ButtonPrompt)

	self:_setup()

	return self
end

function ButtonPrompt.setParent(self: ClassType, parent: Instance, size: UDim2?)
	self._instance.Parent = parent
	self._instance.Size = size or prefabInstance.Size
end

function ButtonPrompt._setup(self: ClassType)
	self:_updateInputDisplay(InputCategorizer.getLast())
	self:_listenForInputChanged()
end

function ButtonPrompt._updateInputDisplay(self: ClassType, inputCategory: InputCategory.EnumType)
	-- Remove old button display
	-- 拆除旧的按钮显示屏
	self._instance:ClearAllChildren()

	if inputCategory == InputCategory.KeyboardAndMouse then
		self:_getButtonDisplayForInput(self._keyboardAndMouseInput)
	elseif inputCategory == InputCategory.Gamepad then
		self:_getButtonDisplayForInput(self._gamepadInput)
	elseif inputCategory == InputCategory.Touch then
		self:_getButtonDisplayForInput(Enum.UserInputType.Touch)
	end
end

function ButtonPrompt._getButtonDisplayForInput(self: ClassType, input: Enum.KeyCode | Enum.UserInputType)
	local gamepadImage
	if input.EnumType == Enum.KeyCode then
		gamepadImage = UserInputService:GetImageForKeyCode(input :: Enum.KeyCode)
	end

	if input == Enum.UserInputType.Touch then
		local touchIcon: ImageLabel = (getInstance(prefabFolder, "TouchImageLabel") :: any):Clone()
		touchIcon.Parent = self._instance
	elseif gamepadImage and gamepadImage ~= "" then
		local gamepadIcon: ImageLabel = (getInstance(prefabFolder, "GamepadImageLabel") :: any):Clone()
		gamepadIcon.Image = gamepadImage
		gamepadIcon.Parent = self._instance
	elseif InputMetadata.MouseButtonImage[input] then
		local mouseIcon: ImageLabel = (getInstance(prefabFolder, "MouseImageLabel") :: any):Clone()
		mouseIcon.Image = InputMetadata.MouseButtonImage[input]
		mouseIcon.Parent = self._instance
	else
		local border: ImageLabel = (getInstance(prefabFolder, "KeyboardBorderImage") :: any):Clone()
		border.Parent = self._instance

		local buttonTextString = UserInputService:GetStringForKeyCode(input :: Enum.KeyCode)

		local buttonTextImage = InputMetadata.KeyboardButtonImage[input]
		if not buttonTextImage then
			buttonTextImage = InputMetadata.KeyboardButtonIconMapping[buttonTextString]
		end

		if not buttonTextImage then
			local keyCodeMappedText = InputMetadata.KeyCodeToTextMapping[input :: Enum.KeyCode]
			if keyCodeMappedText then
				buttonTextString = keyCodeMappedText
			end
		end

		if buttonTextImage then
			local keyboardIcon: ImageLabel = (getInstance(prefabFolder, "KeyboardImageLabel") :: any):Clone()
			keyboardIcon.Image = buttonTextImage
			keyboardIcon.Parent = self._instance
		elseif buttonTextString and buttonTextString ~= "" then
			local keyboardText: TextLabel = (getInstance(prefabFolder, "KeyboardTextLabel") :: any):Clone()
			keyboardText.Text = buttonTextString
			keyboardText.TextSize = InputMetadata.KeyCodeToFontSize[input :: Enum.KeyCode]
				or InputMetadata.DefaultFontSize
			keyboardText.Parent = self._instance
		end
	end
end

function ButtonPrompt.setSize(self: ClassType, size: UDim2)
	self._instance.Size = size
end

function ButtonPrompt._setZIndex(self: ClassType, index: number)
	self._instance.ZIndex = index
	local imagelabel = getInstance(self._instance, "ImageLabel") :: GuiObject
	imagelabel.ZIndex = index
end

function ButtonPrompt._updateVisibility(self: ClassType)
	self._instance.Visible = self._shouldBeVisible and self._isEnabled
end

function ButtonPrompt._setVisible(self: ClassType, isVisible: boolean)
	self._instance.Visible = isVisible
end

function ButtonPrompt.setEnabled(self: ClassType, isEnabled: boolean)
	self._isEnabled = isEnabled
	self:_updateVisibility()
end

function ButtonPrompt._listenForInputChanged(self: ClassType)
	self._inputTypeChangedConnection = InputCategorizer.changed:Connect(function(inputCategory: any?)
		self:_updateInputDisplay(inputCategory :: InputCategory.EnumType)
	end)
end

function ButtonPrompt.destroy(self: ClassType)
	local connection = self._inputTypeChangedConnection :: Signal.SignalConnection
	connection:Disconnect()
	self._instance:Destroy()
end

return ButtonPrompt
