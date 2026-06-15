--!strict

--[[
	This keeps track of the most recent "input category" that scripts can use to
	properly switch between touch, gamepad, and keyboard/mouse interfaces.

	This also provides a changed event and a getter for the last input category.

	An "input category" is a simplified grouping for UserInputTypes, defined below:
		1. Gamepad1 through Gamepad8 are just InputCategory.Gamepad
		2. Keyboard and Mouse input are both InputCategory.KeyboardAndMouse
		3. Touch is InputCategory.KeyboardAndMouse, a 1:1 translation
		4. Everything else is InputCategory.Other

	This is useful for easily comparing one input category string rather than checking
	against a whole list of UserInputTypes.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Signal = require(ReplicatedStorage.ReplicatedCode.Framework.Packages.Signal)
local InputCategory = require(ReplicatedStorage.ReplicatedCode.Framework.Input.InputCategory)


local function getDefaultInputType(): InputCategory.EnumType
	local preferredInput = UserInputService.PreferredInput
	return preferredInput
end

local InputCategorizer = {
	_activeInputType = getDefaultInputType(),
	changed = Signal.new(),
}

function InputCategorizer._setActiveInputCategory(inputCategory: InputCategory.EnumType)
	if InputCategorizer._activeInputType ~= inputCategory then
		InputCategorizer._activeInputType = inputCategory
		InputCategorizer.changed:Fire(InputCategorizer._activeInputType)
	end
end

function InputCategorizer._onInputTypeChanged()
	local inputCategory: InputCategory.EnumType = UserInputService.PreferredInput
	InputCategorizer._setActiveInputCategory(inputCategory)
end

function InputCategorizer.getCategoryOf(): InputCategory.EnumType
	return UserInputService.PreferredInput
end

function InputCategorizer.getLast(): InputCategory.EnumType
	return InputCategorizer._activeInputType
end

function InputCategorizer._setup()
	UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function()
		InputCategorizer._onInputTypeChanged()
	end)
end

InputCategorizer._setup()

return InputCategorizer
