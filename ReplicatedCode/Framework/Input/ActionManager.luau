--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local InputCategorizer = require(ReplicatedStorage.ReplicatedCode.Framework.Input.InputCategorizer)
local InputCategory = require(ReplicatedStorage.ReplicatedCode.Framework.Input.InputCategory)
local ButtonPrompt = require(ReplicatedStorage.ReplicatedCode.Framework.Input.ButtonPrompt)
local Connections = require(ReplicatedStorage.ReplicatedCode.Framework.Infrastructure.Classes.Connections)
local getCodeAsset = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Instance.GetCodeAsset)

local player = Players.LocalPlayer :: Player
local playerGui = player:WaitForChild("PlayerGui")
local instances = getCodeAsset("Input") :: any
local actionGui = instances.ActionGui

local HORIZONTAL_PADDING = 40
local VERTICAL_PADDING = 40

local BIG_BUTTONSIZE = UDim2.fromOffset(60,60)
local SMALL_BUTTONSIZE = UDim2.fromOffset(48,48)

type ActionCallback = (string, Enum.UserInputState, InputObject) -> ...any


export type ClassType = {
	connections :  Connections.ClassType,
	keyboardAndMouseInput : Enum.KeyCode | Enum.UserInputType,
	gamepadInput: Enum.KeyCode | Enum.UserInputType,
	frame : any,
	enabled: boolean,
	buttonPrompt: ButtonPrompt.ClassType
}


local ActionManager = {
	InputCategory = InputCategory,
	_initialized = false,
	_bindings = {} :: { [string]: any },
}

function ActionManager.bindAction(
	actionName: string,
	callback: ActionCallback?,
	keyboardAndMouseInput: Enum.KeyCode | Enum.UserInputType,
	gamepadInput: Enum.KeyCode | Enum.UserInputType,
	displayOrder: number?
)
	-- Make sure action binds aren't overwritten
	-- 确保动作绑定不会被覆盖
	if ActionManager._bindings[actionName] then
		warn(string.format("'%s' is already bound!", actionName))
		return
	end

	local binding = {
		connections = Connections.new(),
		keyboardAndMouseInput = keyboardAndMouseInput,
		gamepadInput = gamepadInput,
		enabled = true,
		buttonPrompt = ButtonPrompt.new(keyboardAndMouseInput, gamepadInput)
	} ::ClassType

	-- Create a new UI element
	-- 创建一个新的用户界面元素
	local actionFrame = instances.ActionFrame:Clone()
	actionFrame.ContentFrame.ActionLabel.Text = actionName
	actionFrame.LayoutOrder = displayOrder or 0
	actionFrame.Parent = actionGui.ListFrame

	binding.frame = actionFrame

	binding.buttonPrompt:setParent(binding.frame.ContentFrame.InputFrame)
	
	
	local beginColor = Color3.fromRGB(77, 77, 77)
	local endColor = Color3.fromRGB(0, 0, 0)
	
	local InputFrame = binding.frame.ContentFrame.InputFrame ::Frame
	if actionName == "Place_Sure" then
		beginColor = Color3.fromRGB(36, 138, 62)
		endColor = Color3.fromRGB(67, 255, 114)
	
	elseif actionName == "Place_Cancel" then
		beginColor = Color3.fromRGB(150, 41, 41)
		endColor = Color3.fromRGB(255, 69, 69)
	end
	InputFrame.BackgroundColor3 = endColor

	-- Create a wrapper for the callback function so the UI can be updated in sync with the action
	-- 为回调函数创建一个封装，以便用户界面能与操作同步更新
	local callbackWrapper = function(...)
		if not binding.enabled then    --一个开关，可以在这里面
			return Enum.ContextActionResult.Pass
		end
		local action, inputState = ...

		if action == actionName then
			if inputState == Enum.UserInputState.Begin then
				actionFrame.ContentFrame.InputFrame.BackgroundColor3 = beginColor
				--actionFrame.ContentFrame.ActionLabel.BackgroundColor3 = Color3.new(1, 1, 1)
				--actionFrame.ContentFrame.ActionLabel.TextColor3 = Color3.new(0, 0, 0)
			elseif inputState == Enum.UserInputState.End then
				actionFrame.ContentFrame.InputFrame.BackgroundColor3 = endColor
				--actionFrame.ContentFrame.ActionLabel.BackgroundColor3 = Color3.new(0, 0, 0)
				--actionFrame.ContentFrame.ActionLabel.TextColor3 = Color3.new(1, 1, 1)
			end
		end
		if callback then
			callback(...)
		end	
		return Enum.ContextActionResult.Pass
	end

	-- Touch button connections
	-- 触摸按钮连接
	local began = actionFrame.TouchButton.InputBegan:Connect(function(inputObject)
		if inputObject.UserInputType == Enum.UserInputType.Touch then
			callbackWrapper(actionName, Enum.UserInputState.Begin, inputObject)
		end
	end)
	
	local ended = actionFrame.TouchButton.InputEnded:Connect(function(inputObject)
		if inputObject.UserInputType == Enum.UserInputType.Touch then
			callbackWrapper(actionName, Enum.UserInputState.End, inputObject)
		end
	end)

	binding.connections:add(began, ended)

	-- Bind the action using ContextActionService
	ContextActionService:BindAction(actionName, callbackWrapper, false, keyboardAndMouseInput, gamepadInput)
	-- Save the binding
	ActionManager._bindings[actionName] = binding
end

function ActionManager.getGui()
	return actionGui.ListFrame
end


function ActionManager.setActionTitle(actionName: string, title: string)
	local binding = ActionManager._bindings[actionName]
	if binding then
		local ActionLabel = binding.frame.ContentFrame.ActionLabel
		ActionLabel.Text = title or actionName

	end
end

function ActionManager.setActionVisibility(actionName: string, isVisible: boolean)
	local binding = ActionManager._bindings[actionName]
	if binding then
		binding.enabled = isVisible
		binding.frame.Visible = isVisible
	end
end

function ActionManager.setActionEnabeld(actionName: string, enabled: boolean)
	local binding = ActionManager._bindings[actionName]
	if binding then
		binding.enabled = enabled
	end
end

function ActionManager.hasbindAction(actionName: string)
	return ActionManager._bindings[actionName]
end

function ActionManager.unbindAction(actionName: string)
	local binding = ActionManager._bindings[actionName] ::ClassType
	if binding then
		-- Disconnect all connections for the binding
		for _, connection in binding.connections do
			connection:Disconnect()
		end
		
		binding.connections:disconnect()
		
		binding.buttonPrompt:destroy()
		
		-- Destroy the UI element for the binding
		binding.frame:Destroy()
	
		ActionManager._bindings[actionName] = nil
	end

	-- Unbind the action from ContextActionService
	ContextActionService:UnbindAction(actionName)
end


-- Return an InputCategory based on the UserInputType
-- 根据用户输入类型返回输入类别
function ActionManager._getCategoryOfInputType(inputType: Enum.UserInputType)
	if string.find(inputType.Name, "Gamepad") then
		return InputCategory.Gamepad
	elseif inputType == Enum.UserInputType.Keyboard or string.find(inputType.Name, "Mouse") then
		return InputCategory.KeyboardAndMouse
	elseif inputType == Enum.UserInputType.Touch then
		return InputCategory.Touch
	else
		return InputCategory.KeyboardAndMouse
	end
end

-- Return a default input category based on the current peripherals
-- 根据当前外设返回默认输入类别
function ActionManager._getDefaultInputCategory()
	if UserInputService.KeyboardEnabled and UserInputService.MouseEnabled then
		return InputCategory.KeyboardAndMouse
	elseif UserInputService.TouchEnabled then
		return InputCategory.Touch
	elseif UserInputService.GamepadEnabled then
		return InputCategory.Gamepad
	else
		return InputCategory.KeyboardAndMouse
	end
end

-- Update the position and scale of the actions list
-- 更新操作列表的位置和缩放比例
--function ActionManager._updatePositionAndScale()
--	local touchControlsEnabled = playerGui:FindFirstChild("TouchGui") ~= nil
--	-- This is the same calculation used by the TouchGui for sizing the jump button
--	-- 这与 TouchGui 用来调整跳跃按钮大小的计算方法相同
--	local minScreenSize = math.min(actionGui.AbsoluteSize.X, actionGui.AbsoluteSize.Y)
--	local isSmallScreen = minScreenSize < 500

--	local verticalPadding = VERTICAL_PADDING
--	if touchControlsEnabled and InputCategorizer.getLastInputCategory() == InputCategory.Touch then
--		-- Offset the vertical padding to account for the jump button
--		-- Note that the jump button can be two sizes depending on if the screen is considered small or not
--		-- 偏移垂直填充，以考虑到跳转按钮
--		-- 注意，跳转按钮有两种尺寸，取决于屏幕是否被视为小尺寸
--		verticalPadding += if isSmallScreen then 70 else 210
--	end

--	-- If the screen is considered 'small', scale the action list down
--	-- 如果屏幕被认为是 "小 "屏幕，则缩小操作列表的尺寸
--	local listFrame = actionGui:FindFirstChild("ListFrame")
--	if listFrame then
--		listFrame.UIScale.Scale = if isSmallScreen then 0.7 else 1
--		listFrame.Position = UDim2.new(1, -HORIZONTAL_PADDING, 1, -verticalPadding)
--	end

--end
function ActionManager._updatePositionAndScale()
	local touchControlsEnabled = playerGui:FindFirstChild("TouchGui") ~= nil
	-- This is the same calculation used by the TouchGui for sizing the jump button
	-- 这与 TouchGui 用来调整跳跃按钮大小的计算方法相同
	local minScreenSize = math.min(actionGui.AbsoluteSize.X, actionGui.AbsoluteSize.Y)
	local isSmallScreen = minScreenSize < 500

	local verticalPadding = VERTICAL_PADDING
	if touchControlsEnabled and InputCategorizer.getLast() == InputCategory.Touch then
		-- Offset the vertical padding to account for the jump button
		-- Note that the jump button can be two sizes depending on if the screen is considered small or not
		-- 偏移垂直填充，以考虑到跳转按钮
		-- 注意，跳转按钮有两种尺寸，取决于屏幕是否被视为小尺寸
		verticalPadding += if isSmallScreen then 70 else 210
	end

	-- If the screen is considered 'small', scale the action list down
	-- 如果屏幕被认为是 "小 "屏幕，则缩小操作列表的尺寸
	local listFrame = actionGui:FindFirstChild("ListFrame")
	if listFrame then
		listFrame.UIScale.Scale = if isSmallScreen then 0.725 else 1
		listFrame.Position = UDim2.new(1, -HORIZONTAL_PADDING, 1, -verticalPadding)
		--listFrame.Position = UDim2.new(1, -verticalPadding, 1, -HORIZONTAL_PADDING/2)
		--listFrame.Position = UDim2.new(1, -HORIZONTAL_PADDING, 1, -verticalPadding)
		listFrame.Size = isSmallScreen and BIG_BUTTONSIZE or SMALL_BUTTONSIZE
	end

end


function ActionManager._initialize()
	assert(not ActionManager._initialized, "ActionManager already initialized!")
	assert(RunService:IsClient(), "ActionManager can only be used on the client!")

	-- Update the position and scale of the list if the TouchGui is added/removed
	-- 如果添加/删除 TouchGui，更新列表的位置和缩放比例
	playerGui.ChildAdded:Connect(function(child)
		if child.Name == "TouchGui" then
			ActionManager._updatePositionAndScale()
		end
	end)

	playerGui.ChildRemoved:Connect(function(child)
		if child.Name == "TouchGui" then
			ActionManager._updatePositionAndScale()
		end
	end)

	-- Update the position and scale of the list when the screen size changes or last input category changes
	-- 当屏幕尺寸发生变化或最后一个输入类别发生变化时，更新列表的位置和缩放比例
	actionGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(ActionManager._updatePositionAndScale)
	InputCategorizer.changed:Connect(ActionManager._updatePositionAndScale)

	-- Parent the UI to the player gui and update its position and scale
	-- 将用户界面作为播放器界面的父界面，并更新其位置和缩放比例
	actionGui.Parent = playerGui
	ActionManager._updatePositionAndScale()

	ActionManager._initialized = true
end

ActionManager._initialize()

return ActionManager
