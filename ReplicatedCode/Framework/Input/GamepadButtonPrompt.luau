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

local prefabFolder: Folder = getCodeAsset("Input", "GamepadButtonPrompt")
local prefabInstance: Frame = (getInstance(prefabFolder, "GamepadInputIconPrefab") :: any) :: Frame

local GamepadButtonPrompt = {}
GamepadButtonPrompt.__index = GamepadButtonPrompt

export type ClassType = typeof(setmetatable(
	{} :: {
		_instance: Frame,
		_isEnabled: boolean,
		_shouldBeVisible: boolean,
		_inputTypeChangedConnection: Signal.SignalConnection?,
	},
	GamepadButtonPrompt
))

function GamepadButtonPrompt.new(keyCode: Enum.KeyCode): ClassType
	local self = {
		_instance = prefabInstance:Clone() :: Frame,
		_inputTypeChangedConnection = nil :: Signal.SignalConnection?,
		_isEnabled = true,
		_shouldBeVisible = false,
	}
	setmetatable(self, GamepadButtonPrompt)

	self:_setup(keyCode)

	return self
end

function GamepadButtonPrompt.setParent(self: ClassType, parent: Instance, size: UDim2?)
	self._instance.Parent = parent
	self._instance.Size = size or prefabInstance.Size
end

function GamepadButtonPrompt._setup(self: ClassType, keyCode: Enum.KeyCode)
	self:_setIcon(keyCode)
	self:_listenForInputChanged()
end

function GamepadButtonPrompt._setIcon(self: ClassType, keyCode: Enum.KeyCode)
	local imageLabel: ImageLabel = getInstance(self._instance, "ImageLabel") ::ImageLabel
	--formatImageForKeyCode(imageLabel, keyCode)
	imageLabel.Image = UserInputService:GetImageForKeyCode(keyCode :: Enum.KeyCode)
end

function GamepadButtonPrompt._listenForInputChanged(self: ClassType)
	self:_onInput(InputCategorizer.getLast())
	self._inputTypeChangedConnection = InputCategorizer.changed:Connect(function(inputCategory: any?)
		self:_onInput(inputCategory :: InputCategory.EnumType)
	end)
end

function GamepadButtonPrompt._onInput(self: ClassType, inputCategory: InputCategory.EnumType)
	if inputCategory == InputCategory.Gamepad then
		self:_onGamepadInput()
	else
		self:_onNonGamepadInput()
	end
end

function GamepadButtonPrompt._setZIndex(self: ClassType, index: number)
	self._instance.ZIndex = index
	local image = getInstance(self._instance, "ImageLabel") :: GuiObject
	image.ZIndex = index
end

function GamepadButtonPrompt._updateVisibility(self: ClassType)
	self._instance.Visible = self._shouldBeVisible and self._isEnabled
end

function GamepadButtonPrompt._onGamepadInput(self: ClassType)
	self._shouldBeVisible = true
	self:_updateVisibility()
end

function GamepadButtonPrompt._onNonGamepadInput(self: ClassType)
	self._shouldBeVisible = false
	self:_updateVisibility()
end

function GamepadButtonPrompt._setVisible(self: ClassType, isVisible: boolean)
	self._instance.Visible = isVisible
end

function GamepadButtonPrompt.setEnabled(self: ClassType, isEnabled: boolean)
	self._isEnabled = isEnabled
	self:_updateVisibility()
end

function GamepadButtonPrompt.destroy(self: ClassType)
	local connection = self._inputTypeChangedConnection :: Signal.SignalConnection
	connection:Disconnect()
	self._instance:Destroy()
end

return GamepadButtonPrompt
