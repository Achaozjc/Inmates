--!strict

--[[
	Adds hovering animations and an "×" label with a button component
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local GamepadButtonPrompt = require(ReplicatedStorage.ReplicatedCode.Framework.Input.GamepadButtonPrompt)
local Button = require(script.Parent.Button)
local Keybind = require(ReplicatedStorage.ReplicatedCode.Framework.Input.Keybind)
local getInstance = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Instance.GetInstance)
local getCodeAsset = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Instance.GetCodeAsset)
local KeyCodeBindingInfo = require(ReplicatedStorage.ReplicatedCode.Framework.Input.KeyCodeBindingInfo)
local Connections = require(ReplicatedStorage.ReplicatedCode.Framework.Infrastructure.Classes.Connections)

local prefabFolder: Folder = getCodeAsset("UI", "CloseButton")
local prefabInstance: Frame = (getInstance(prefabFolder, "CloseButtonFramePrefab") :: any) :: Frame
local prefabImageLabel: ImageLabel = (getInstance(prefabFolder, "Contents", "Label") :: any) :: ImageLabel

local CLOSE_IMAGE_COLOR = prefabImageLabel.ImageColor3
local CLOSE_IMAGE_COLOR_HOVER = Color3.fromRGB(255, 116, 116)
local CLOSE_IMAGE_COLOR_DISABLED = Color3.fromRGB(131, 0, 0)
local TWEEN_INFO = TweenInfo.new(0.1)


local CloseButton = {}
CloseButton.__index = CloseButton

export type ClassType = typeof(setmetatable(
	{} :: {
		_button: Button.ClassType,
		_gamepadButtonPrompt: GamepadButtonPrompt.ClassType,
		_instance: GuiButton,
		_isEnabled: boolean,
		_connections: Connections.ClassType,
		_tweenIn: Tween?,
		_tweenOut: Tween?,
		_tweenDisabled: Tween?,
	},
	CloseButton
	))

function CloseButton.new(instance :GuiButton): ClassType

	local self = setmetatable({
		_button = Button.new(instance, KeyCodeBindingInfo.Close),
		_gamepadButtonPrompt = GamepadButtonPrompt.new(Keybind.GamepadBackAction),
		_instance = instance,
		_isEnabled = true,
		_connections = Connections.new(),
		_tweenIn = nil,
		_tweenOut = nil,
		_tweenDisabled = nil,
	}, CloseButton) :: ClassType

	self:_setup()

	return self
end

function CloseButton.setParent(self: ClassType, parent: Instance)
	self._instance.Parent = parent
end

function CloseButton._setup(self: ClassType)

	self._gamepadButtonPrompt:setParent(self._instance,  UDim2.new(.5,0,.5,0))

	self:_setupTweens()
	self:_setupConnections()
	self._button:setSelectable(false)
end

function CloseButton.getButton(self: ClassType)
	return self._button
end

function CloseButton.getInstance(self: ClassType)
	return self._instance
end

function CloseButton._setupTweens(self: ClassType)
	local textLabel: GuiObject = getInstance(self._instance, "Label")
	if textLabel:IsA("TextLabel") then
		self._tweenIn = TweenService:Create(textLabel, TWEEN_INFO, { TextColor3 = CLOSE_IMAGE_COLOR_HOVER })
		self._tweenOut = TweenService:Create(textLabel, TWEEN_INFO, { TextColor3 = CLOSE_IMAGE_COLOR })
		self._tweenDisabled = TweenService:Create(textLabel, TWEEN_INFO, { TextColor3 = CLOSE_IMAGE_COLOR_DISABLED })
	else
		self._tweenIn = TweenService:Create(textLabel, TWEEN_INFO, { ImageColor3 = CLOSE_IMAGE_COLOR_HOVER })
		self._tweenOut = TweenService:Create(textLabel, TWEEN_INFO, { ImageColor3 = CLOSE_IMAGE_COLOR })
		self._tweenDisabled = TweenService:Create(textLabel, TWEEN_INFO, { ImageColor3 = CLOSE_IMAGE_COLOR_DISABLED })
	end
	
end

function CloseButton._setupConnections(self: ClassType)
	assert(
		self._tweenIn and self._tweenOut and self._tweenDisabled,
		"setupTweens must be called before setupConnections"
	)

	local hoveredConnection = self._button.hovered:Connect(function(isHovering: any)
		if not self._isEnabled then
			return
		end

		if isHovering :: boolean then
			self._tweenIn:Play()
		else
			self._tweenOut:Play()
		end
	end)
	
	local activatedConnection = self._button.activated:Connect(function()
		SoundService.SFX.Close:Play()

	end)

	self._connections:add(activatedConnection,hoveredConnection)
	
end

function CloseButton.setEnabled(self: ClassType, isEnabled: boolean)
	self._isEnabled = isEnabled
	self._gamepadButtonPrompt:setEnabled(isEnabled)
	self._button:setEnabled(isEnabled)

	if isEnabled then
		local tweenOut = self._tweenOut :: Tween
		tweenOut:Play()
	else
		local tweenDisabled = self._tweenDisabled :: Tween
		tweenDisabled:Play()
	end
end


function CloseButton.setVisible(self: ClassType, visible: boolean)
	self._instance.Visible = visible
end


function CloseButton.destroy(self: ClassType)
	self._connections:disconnect()
	self._button:destroy()
	self._gamepadButtonPrompt:destroy()
	self._instance:Destroy()
end

return CloseButton

