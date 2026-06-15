--!strict

--[[
	GuideHintStyle
	新手引导提示文案层：PlayerGui.TutorialHintGui（独立 ScreenGui）+ 顶部单张提示卡片。
	卡片由代码构建；ScreenGui 下挂 UIScale 并打 UI_Scale 标签，由 GUIScale 组件统一缩放。
	多系统可共用：按 owner 引用计数控制显隐，避免互相误关。
]]

export type HintParts = {
	card: Frame,
	label: TextLabel,
}

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TagCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.TagCategory)

local GuideHintStyle = {}

GuideHintStyle.SCREEN_GUI_NAME = "TutorialHintGui"
GuideHintStyle.DISPLAY_ORDER = 55

GuideHintStyle.CARD_WIDTH_PX = 400
GuideHintStyle.CARD_HEIGHT_PX = 130
GuideHintStyle.TEXT_SIZE = 30
GuideHintStyle.PAD_LEFT = 16
GuideHintStyle.PAD_RIGHT = 14
GuideHintStyle.PAD_TOP = 16
GuideHintStyle.PAD_BOTTOM = 12

GuideHintStyle.ANCHOR_POINT = Vector2.new(0.5, 0)
GuideHintStyle.POSITION = UDim2.fromScale(0.5, 0.12)
GuideHintStyle.SIZE = UDim2.fromOffset(GuideHintStyle.CARD_WIDTH_PX, GuideHintStyle.CARD_HEIGHT_PX)

GuideHintStyle.OWNER_TUTORIAL = "tutorial"

local PANEL_BG_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(42, 42, 46)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(72, 72, 80)),
})

local _screenGui: ScreenGui? = nil
local _parts: HintParts? = nil
-- 共用同一 ScreenGui：按 owner 引用计数，任一 owner 可见即启用
local _visibleOwners: { [string]: boolean } = {}

local function refreshScreenGuiEnabled()
	if _screenGui then
		_screenGui.Enabled = next(_visibleOwners) ~= nil
	end
end

local function attachUIScale(screenGui: ScreenGui)
	local existing = screenGui:FindFirstChildOfClass("UIScale")
	if existing and CollectionService:HasTag(existing, TagCategory.UI_Scale) then
		return
	end
	if existing then
		existing:Destroy()
	end

	local uiScale = Instance.new("UIScale")
	uiScale.Parent = screenGui
	CollectionService:AddTag(uiScale, TagCategory.UI_Scale)
end

local function createCard(parent: Instance): HintParts
	local root = Instance.new("Frame")
	root.Name = "TutorialHintCard"
	root.AnchorPoint = GuideHintStyle.ANCHOR_POINT
	root.Position = GuideHintStyle.POSITION
	root.Size = GuideHintStyle.SIZE
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.ClipsDescendants = false
	root.Active = false
	root.Visible = true

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = Color3.fromRGB(48, 48, 52)
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.Parent = root

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 18)
	panelCorner.Parent = panel

	local panelGradient = Instance.new("UIGradient")
	panelGradient.Color = PANEL_BG_GRADIENT
	panelGradient.Rotation = 135
	panelGradient.Parent = panel

	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = Color3.fromRGB(0, 0, 0)
	panelStroke.Thickness = 2
	panelStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	panelStroke.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, GuideHintStyle.PAD_TOP)
	padding.PaddingBottom = UDim.new(0, GuideHintStyle.PAD_BOTTOM)
	padding.PaddingLeft = UDim.new(0, GuideHintStyle.PAD_LEFT)
	padding.PaddingRight = UDim.new(0, GuideHintStyle.PAD_RIGHT)
	padding.Parent = panel

	local iconBadge = Instance.new("Frame")
	iconBadge.Name = "AlertIcon"
	iconBadge.AnchorPoint = Vector2.new(0, 0)
	iconBadge.Position = UDim2.new(0, -6, 0, -6)
	iconBadge.Size = UDim2.fromOffset(32, 32)
	iconBadge.BackgroundColor3 = Color3.fromRGB(235, 55, 55)
	iconBadge.BorderSizePixel = 0
	iconBadge.ZIndex = 3
	iconBadge.Parent = root

	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(1, 0)
	iconCorner.Parent = iconBadge

	local iconStroke = Instance.new("UIStroke")
	iconStroke.Color = Color3.fromRGB(0, 0, 0)
	iconStroke.Thickness = 1.5
	iconStroke.Parent = iconBadge

	local iconText = Instance.new("TextLabel")
	iconText.Name = "Glyph"
	iconText.Size = UDim2.fromScale(1, 1)
	iconText.BackgroundTransparency = 1
	iconText.Font = Enum.Font.GothamBold
	iconText.Text = "!"
	iconText.TextColor3 = Color3.fromRGB(255, 255, 255)
	iconText.TextScaled = true
	iconText.ZIndex = 4
	iconText.Parent = iconBadge

	local label = Instance.new("TextLabel")
	label.Name = "Message"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextSize = GuideHintStyle.TEXT_SIZE
	label.TextWrapped = true
	label.TextScaled = false
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Text = ""
	label.ZIndex = 2
	label.Parent = panel

	root.Parent = parent

	return { card = root, label = label }
end

-- 代码构建提示卡片（重复调用幂等）
function GuideHintStyle.init(playerGui: PlayerGui)
	if _screenGui and _parts then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = GuideHintStyle.SCREEN_GUI_NAME
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = GuideHintStyle.DISPLAY_ORDER
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	gui.Parent = playerGui

	attachUIScale(gui)

	_screenGui = gui
	_parts = createCard(gui)
end

function GuideHintStyle.getParts(): HintParts?
	return _parts
end

function GuideHintStyle.setMessage(text: string)
	if _parts then
		_parts.label.Text = text
	end
end

function GuideHintStyle.acquire(owner: string)
	_visibleOwners[owner] = true
	refreshScreenGuiEnabled()
end

function GuideHintStyle.release(owner: string)
	_visibleOwners[owner] = nil
	refreshScreenGuiEnabled()
end

function GuideHintStyle.show()
	GuideHintStyle.acquire(GuideHintStyle.OWNER_TUTORIAL)
end

function GuideHintStyle.hide()
	GuideHintStyle.release(GuideHintStyle.OWNER_TUTORIAL)
end

return GuideHintStyle
