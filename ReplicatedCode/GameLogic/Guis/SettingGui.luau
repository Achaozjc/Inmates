--!strict

--[[
	设置面板：音效 / 音乐音量滑条。
	StarterGui 预制体：GUI_Setting（结构移植自 spicy Setting）
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Framework = ReplicatedStorage.ReplicatedCode.Framework
local GameLogic = ReplicatedStorage.ReplicatedCode.GameLogic

local GuiBase = require(Framework.UI.GuiBase)
local UILayerId = require(Framework.UI.UILayerId)
local UILayerType = require(Framework.UI.UILayerType)
local UILayerHandler = require(Framework.UI.UILayerHandler)
local Network = require(Framework.Core.Network)
local PlayerDataClient = require(Framework.DataStore.PlayerDataClient)
local VolumeManager = require(Framework.Managers.VolumeManager)
local RemoteFunctionKey = require(GameLogic.SharedConstants.Keys.RemoteFunctionKey)
local PlayerDataKey = require(GameLogic.SharedConstants.Keys.PlayerDataKey)
local AttributeEnum = require(GameLogic.Shared.Enums.AttributeEnum)

local SettingGui = GuiBase.new(UILayerId.GUI_Setting, UILayerType.Menu)

local sliderApplySaved: { (setting: { [string]: any }?) -> () } = {}

local function currentSetting(): { [string]: any }?
	if PlayerDataClient.hasLoaded() then
		return PlayerDataClient.get(PlayerDataKey.Setting)
	end
	return nil
end

local function findByPath(root: Instance, path: string): Instance?
	local node: Instance? = root
	for seg in string.gmatch(path, "[^%.]+") do
		if not node then
			return nil
		end
		node = (node :: Instance):FindFirstChild(seg)
	end
	return node
end

local function applyAudioVolume(settingKey: string, percent: number)
	local fraction = math.clamp(percent, 0, 100) / 100
	VolumeManager.set(settingKey, fraction)
end

local function setupSlider(
	knob: GuiObject,
	button: GuiObject,
	bar: GuiObject,
	settingKey: string?
)
	local dragging = false
	local currentPercent = 50

	local function applyPercent(percent: number)
		percent = math.clamp(percent, 0, 100)
		currentPercent = percent

		local barLeftScale = bar.Position.X.Scale - bar.Size.X.Scale * bar.AnchorPoint.X
		local targetScaleX = barLeftScale + (percent / 100) * bar.Size.X.Scale
		knob.Position = UDim2.new(targetScaleX, 0, knob.Position.Y.Scale, knob.Position.Y.Offset)

		local valueText = tostring(math.round(percent))
		for _, lbl in ipairs(knob:GetDescendants()) do
			if lbl:IsA("TextLabel") then
				(lbl :: TextLabel).Text = valueText
			end
		end

		if settingKey then
			applyAudioVolume(settingKey, percent)
		end
	end

	local function persist()
		if not settingKey then
			return
		end
		local percent = currentPercent
		task.spawn(function()
			Network.invokeServerAsync(RemoteFunctionKey.Change_Settings, settingKey, percent)
		end)
	end

	local function percentFromX(x: number): number
		local w = bar.AbsoluteSize.X
		if w <= 0 then
			return 0
		end
		return math.clamp((x - bar.AbsolutePosition.X) / w, 0, 1) * 100
	end

	local function beginDrag(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			applyPercent(percentFromX(input.Position.X))
		end
	end

	button.InputBegan:Connect(beginDrag)
	bar.InputBegan:Connect(beginDrag)

	UserInputService.InputChanged:Connect(function(input: InputObject)
		if not dragging then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch then
			applyPercent(percentFromX(input.Position.X))
		end
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			if dragging then
				dragging = false
				persist()
			end
		end
	end)

	local function applySaved(setting: { [string]: any }?)
		local saved = settingKey and setting and setting[settingKey]
		local percent = if typeof(saved) == "number" then saved else 50
		applyPercent(percent)
	end

	applySaved(currentSetting())
	table.insert(sliderApplySaved, applySaved)
end

local function applySavedToAll(setting: { [string]: any }?)
	for _, apply in ipairs(sliderApplySaved) do
		apply(setting)
	end
end

local function buildSliders(gui: ScreenGui)
	local root = gui:FindFirstChild("Main") or gui:FindFirstChild("Frame") or gui

	local soundContent = findByPath(root, "Content.SoundSetting.Content")
	if soundContent then
		local knob = soundContent:FindFirstChild("SettingThing") :: GuiObject?
		local bar = soundContent:FindFirstChild("BarFull") :: GuiObject?
		local btn = knob and knob:FindFirstChild("Amount") :: GuiObject?
		if knob and bar then
			setupSlider(knob, (btn or knob) :: GuiObject, bar, AttributeEnum.Setting.sfx)
		end
	end

	local musicContent = findByPath(root, "Content.MusicSetting.Content")
	if musicContent then
		local knob = musicContent:FindFirstChild("idkvro") :: GuiObject?
		local bar = musicContent:FindFirstChild("Barnotfull") :: GuiObject?
		if knob and bar then
			setupSlider(knob, knob, bar, AttributeEnum.Setting.bgm)
		end
	end
end

function SettingGui:start()
	local gui = self:bindScreenGui()
	buildSliders(gui)

	if PlayerDataClient.hasLoaded() then
		applySavedToAll(currentSetting())
	else
		local conn: RBXScriptConnection?
		conn = PlayerDataClient.loaded:Connect(function()
			if conn then
				conn:Disconnect()
				conn = nil
			end
			applySavedToAll(PlayerDataClient.get(PlayerDataKey.Setting))
		end)
	end

	local root = gui:FindFirstChild("Main") or gui:FindFirstChild("Frame") or gui
	local exitBtn = findByPath(root, "Header.ExitButton")
		or findByPath(root, "Top.CloseButton")
	if exitBtn and exitBtn:IsA("GuiButton") then
		(exitBtn :: GuiButton).Activated:Connect(function()
			UILayerHandler.hide(self.Name)
		end)
	end

	if self.switchSignal then
		self.switchSignal.Event:Connect(function(isVisible: boolean)
			if isVisible then
				applySavedToAll(currentSetting())
			end
		end)
	end
end

function SettingGui:listen() end

return SettingGui
