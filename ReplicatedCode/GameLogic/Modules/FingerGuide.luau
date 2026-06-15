--!strict
--[[
	FingerGuide — 轻量手指点击提示

	视觉实例来自 StarterGui.FingerGuideGui（加入后自动复制到 PlayerGui）。
	本模块只做视觉提示，不拦截输入。
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() :: Player
local BindStarterGui = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.UI.BindStarterGui)

local FINGER_GUIDE_GUI_NAME = "FingerGuideGui"

local DEFAULT_SIZE = Vector2.new(72, 72)
local DEFAULT_OFFSET = Vector2.new(18, 14)
local TAP_OFFSET = Vector2.new(0, 9)
local TAP_SCALE = 0.92
local TAP_TWEEN = TweenInfo.new(0.46, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

local FingerGuide = {}

local _gui: ScreenGui? = nil
local _root: Frame? = nil
local _holder: Frame? = nil
local _image: ImageLabel? = nil
local _target: GuiObject? = nil
local _imageId: string? = nil
local _size = DEFAULT_SIZE
local _offset = DEFAULT_OFFSET
local _tapTween: Tween? = nil
local _posConn: RBXScriptConnection? = nil
local _sizeConn: RBXScriptConnection? = nil
local _heartbeatConn: RBXScriptConnection? = nil

local function _findDescendantOfClass(root: Instance, className: string): Instance?
	for _, descendant in root:GetDescendants() do
		if descendant.ClassName == className then
			return descendant
		end
	end
	return nil
end

local function _ensureGui()
	if _gui and _root and _holder and _image then
		return
	end

	local gui = BindStarterGui.waitForScreenGui(FINGER_GUIDE_GUI_NAME, player)
	gui.ResetOnSpawn = false
	gui.Enabled = false

	local root = gui:FindFirstChild("Root", true)
	if not (root and root:IsA("Frame")) then
		root = _findDescendantOfClass(gui, "Frame")
	end

	local holder = if root then root:FindFirstChild("FingerHolder", true) else nil
	if not (holder and holder:IsA("Frame")) and root then
		holder = _findDescendantOfClass(root, "Frame")
	end

	local image = if holder then holder:FindFirstChild("Finger", true) else nil
	if not (image and image:IsA("ImageLabel")) and holder then
		image = _findDescendantOfClass(holder, "ImageLabel")
	end

	if not (root and root:IsA("Frame") and holder and holder:IsA("Frame") and image and image:IsA("ImageLabel")) then
		warn("[FingerGuide] FingerGuideGui prefab must contain Root(Frame), FingerHolder(Frame), and Finger(ImageLabel).")
		gui:Destroy()
		return
	end

	local rootFrame = root :: Frame
	local holderFrame = holder :: Frame
	local imageLabel = image :: ImageLabel

	if _imageId then
		imageLabel.Image = _imageId
	end

	_gui = gui
	_root = rootFrame
	_holder = holderFrame
	_image = imageLabel
end

local function _stopTween()
	if _tapTween then
		_tapTween:Cancel()
		_tapTween = nil
	end
end

local function _disconnectFollow()
	if _posConn then
		_posConn:Disconnect()
		_posConn = nil
	end
	if _sizeConn then
		_sizeConn:Disconnect()
		_sizeConn = nil
	end
	if _heartbeatConn then
		_heartbeatConn:Disconnect()
		_heartbeatConn = nil
	end
end

local function _targetParentScalePosition(target: GuiObject): UDim2?
	local holder = _holder
	if not holder then
		return nil
	end

	local parent = holder.Parent
	if not (parent and parent:IsA("GuiObject")) then
		return nil
	end

	local parentSize = parent.AbsoluteSize
	if parentSize.X <= 0 or parentSize.Y <= 0 then
		return nil
	end

	local centerAbs = target.AbsolutePosition + target.AbsoluteSize * 0.5
	local localPosition = centerAbs + _offset - parent.AbsolutePosition
	return UDim2.fromScale(localPosition.X / parentSize.X, localPosition.Y / parentSize.Y)
end

local function _updatePosition()
	local holder = _holder
	local target = _target
	if not holder or not target or not target.Parent then
		return
	end

	local basePosition = _targetParentScalePosition(target)
	if basePosition then
		holder.Position = basePosition
	end
end

local function _startTap()
	local holder = _holder
	local image = _image
	if not holder or not image then
		return
	end

	_stopTween()
	holder.Size = UDim2.fromOffset(_size.X, _size.Y)
	image.Position = UDim2.fromOffset(0, 0)
	image.Size = UDim2.fromScale(1, 1)
	if _imageId then
		image.Image = _imageId
	end

	_tapTween = TweenService:Create(image, TAP_TWEEN, {
		Position = UDim2.fromOffset(TAP_OFFSET.X, TAP_OFFSET.Y),
		Size = UDim2.fromScale(TAP_SCALE, TAP_SCALE),
	})
	_tapTween:Play()
end

local function _realign()
	local target = _target
	if not target or not target.Parent then
		FingerGuide.hide()
		return
	end

	_updatePosition()
end

function FingerGuide.setImage(imageId: string)
	_imageId = imageId
	if _image then
		_image.Image = imageId
	end
end

function FingerGuide.show(target: GuiObject, offset: Vector2?, size: Vector2?)
	_ensureGui()
	_disconnectFollow()

	_target = target
	_offset = offset or DEFAULT_OFFSET
	_size = size or DEFAULT_SIZE

	local gui = _gui
	if gui then
		gui.Enabled = true
	end

	_realign()
	_startTap()
	task.defer(function()
		RunService.Heartbeat:Wait()
		if _target == target and _gui and _gui.Enabled then
			_realign()
		end
	end)

	_posConn = target:GetPropertyChangedSignal("AbsolutePosition"):Connect(_realign)
	_sizeConn = target:GetPropertyChangedSignal("AbsoluteSize"):Connect(_realign)
	_heartbeatConn = RunService.Heartbeat:Connect(function()
		if not target.Parent then
			FingerGuide.hide()
			return
		end
		_updatePosition()
	end)
end

function FingerGuide.hide()
	_disconnectFollow()
	_stopTween()
	_target = nil
	if _gui then
		_gui.Enabled = false
	end
end

return FingerGuide
