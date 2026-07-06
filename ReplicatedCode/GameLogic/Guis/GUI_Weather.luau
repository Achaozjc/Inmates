--!strict

--[[
	GUI_Weather
	屏幕当前天气 HUD（移植自 dingdong EnvironmentBuffHudGui，不含 Admin Abuse）。

	预制体（StarterGui / PlayerGui）名称：GUI_Weather
	推荐结构（与 dingdong 一致，也兼容多一层 Frame 包裹）：
	  GUI_Weather (ScreenGui)
	    IconButton (ImageButton / TextButton / Frame)
	      IconImage (ImageLabel，可选；ImageButton 自身也可作图标）
	    Panel (Frame)
	      TextLabel

	始终显示 IconButton；点击展开/收起 Panel 详情。晴天时 Panel 提示无事发生。
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = ReplicatedStorage.ReplicatedCode.Framework
local GameLogic = ReplicatedStorage.ReplicatedCode.GameLogic

local GuiBase = require(Framework.UI.GuiBase)
local UILayerId = require(Framework.UI.UILayerId)
local UILayerType = require(Framework.UI.UILayerType)
local AttributeEnum = require(GameLogic.Shared.Enums.AttributeEnum)
local WeatherCategory = require(GameLogic.SharedConstants.Categories.WeatherCategory)
local WeatherEnum = require(GameLogic.Shared.Enums.WeatherEnum)
local EnvironmentBuffHelper = require(GameLogic.Shared.Weather.EnvironmentBuffHelper)

local GUI_Weather = GuiBase.new(UILayerId.GUI_Weather, UILayerType.HeadsUpDisplay)

-- Studio 预制体若仍叫 EnvironmentBuffHudGui，自动回退绑定（layerId 仍为 GUI_Weather）
local SCREEN_GUI_FALLBACK_NAMES = { "EnvironmentBuffHudGui" }

type BuffInfo = {
	woodProductionCdMultiplier: number,
	woodCollectBonusPercent: number,
	moneyCollectMultiplier: number,
	processorSpeedMultiplier: number,
	currentWeather: string,
}

local _visible = false
local _uiReady = false
local _activateTarget: GuiButton? = nil
local _iconImageLabel: ImageLabel? = nil
local _panel: Frame? = nil
local _textLabel: TextLabel? = nil
local _iconContainer: GuiObject? = nil

local function colorToRgb(color: Color3): (number, number, number)
	return math.floor(color.R * 255), math.floor(color.G * 255), math.floor(color.B * 255)
end

local function fontColor(text: string, color: Color3): string
	local r, g, b = colorToRgb(color)
	return string.format('<font color="rgb(%d,%d,%d)">%s</font>', r, g, b, text)
end

local function normalizeAssetImageUri(value: any): string
	if type(value) ~= "string" and type(value) ~= "number" then
		return ""
	end

	local raw = tostring(value)
	if raw == "" then
		return ""
	end

	if string.sub(raw, 1, 11) == "rbxthumb://" then
		return raw
	end
	if string.match(raw, "^https?://") then
		return raw
	end

	local id = string.match(raw, "(%d+)")
	if id then
		return "rbxassetid://" .. id
	end

	return raw
end

local function highlightLine(line: string): string
	return line:gsub("(x%d+%.?%d*)", function(x)
		return fontColor(x, Color3.fromRGB(255, 220, 120))
	end)
end

local function buildEffectsText(info: BuffInfo): string
	if info.currentWeather == WeatherCategory.Sunny then
		local sunnyLine = highlightLine("Weather: Sunny")
		return sunnyLine .. "\nNothing special is happening."
	end

	local lines: { string } = {}
	local weatherInfo = WeatherEnum.Weather[info.currentWeather :: WeatherCategory.EnumType]
	local displayName = if weatherInfo then weatherInfo.name else info.currentWeather

	table.insert(lines, string.format("Weather: %s", displayName))

	if weatherInfo and weatherInfo.des ~= "" then
		table.insert(lines, weatherInfo.des)
	end

	for i, line in ipairs(lines) do
		lines[i] = highlightLine(line)
	end

	return table.concat(lines, "\n")
end

local function bindScreenGuiWithFallback(self: any): ScreenGui?
	local player = self.player
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

	local primaryName: string = self._layerId
	local inst = playerGui:FindFirstChild(primaryName)
	if inst and inst:IsA("ScreenGui") then
		self.Gui = inst
		return inst
	end

	for _, fallbackName in SCREEN_GUI_FALLBACK_NAMES do
		local fallback = playerGui:FindFirstChild(fallbackName)
		if fallback and fallback:IsA("ScreenGui") then
			self.Gui = fallback
			return fallback
		end
	end

	return self:bindScreenGui(primaryName)
end

local function findClickable(root: Instance): GuiButton?
	if root:IsA("GuiButton") then
		return root
	end
	return root:FindFirstChildWhichIsA("GuiButton", true)
end

local function findIconImage(root: Instance): ImageLabel?
	local named = root:FindFirstChild("IconImage", true)
	if named and named:IsA("ImageLabel") then
		return named
	end
	if root:IsA("ImageLabel") then
		return root
	end
	if root:IsA("ImageButton") then
		return root :: ImageLabel
	end
	return nil
end

local function bindUi(gui: ScreenGui): boolean
	local iconRoot = gui:FindFirstChild("IconButton", true)
	local panel = gui:FindFirstChild("Panel", true)

	if not iconRoot then
		warn("[GUI_Weather] 未找到 IconButton，请检查 StarterGui/GUI_Weather 预制体")
		return false
	end
	if not panel or not panel:IsA("Frame") then
		warn("[GUI_Weather] 未找到 Panel (Frame)，请检查 StarterGui/GUI_Weather 预制体")
		return false
	end

	local activateTarget = findClickable(iconRoot)
	if not activateTarget then
		warn("[GUI_Weather] IconButton 下未找到可点击的 ImageButton/TextButton")
		return false
	end

	local iconImage = findIconImage(iconRoot)
	if not iconImage then
		warn("[GUI_Weather] IconButton 下未找到 IconImage (ImageLabel)")
		return false
	end

	local textLabel = panel:FindFirstChildWhichIsA("TextLabel", true)
	if not textLabel then
		warn("[GUI_Weather] Panel 下未找到 TextLabel")
		return false
	end

	_iconContainer = if iconRoot:IsA("GuiObject") then iconRoot else activateTarget
	_activateTarget = activateTarget
	_iconImageLabel = iconImage
	_panel = panel
	_textLabel = textLabel
	textLabel.RichText = true
	panel.Visible = false

	if not _uiReady then
		activateTarget.Activated:Connect(function()
			if not _visible or not _panel then
				return
			end
			_panel.Visible = not _panel.Visible
		end)
	end

	_uiReady = true
	return true
end

local function setActive(active: boolean)
	_visible = active
	local iconContainer = _iconContainer
	local panel = _panel
	if iconContainer then
		iconContainer.Visible = active
	end
	if not active and panel then
		panel.Visible = false
	end
end

local function updateDisplay()
	local gui = GUI_Weather.Gui
	if not gui then
		return
	end

	if not _uiReady and not bindUi(gui) then
		return
	end

	local iconImageLabel = _iconImageLabel
	local textLabel = _textLabel
	if not iconImageLabel or not textLabel then
		return
	end

	local info = EnvironmentBuffHelper.getBuffInfo()
	setActive(true)

	local iconImage = WeatherEnum.getIcon(info.currentWeather :: WeatherCategory.EnumType)
	iconImageLabel.Image = normalizeAssetImageUri(iconImage)
	textLabel.Text = buildEffectsText(info)
end

function GUI_Weather:start()
	local gui = bindScreenGuiWithFallback(self)
	if not gui then
		return
	end

	if not bindUi(gui) then
		return
	end

	updateDisplay()
end

function GUI_Weather:listen()
	ReplicatedStorage:GetAttributeChangedSignal(AttributeEnum.CurrentWeather):Connect(updateDisplay)
	ReplicatedStorage:GetAttributeChangedSignal(AttributeEnum.WeatherDuration):Connect(updateDisplay)

	if self.switchSignal then
		self.switchSignal.Event:Connect(function(isVisible: boolean)
			if isVisible then
				updateDisplay()
			end
		end)
	end

	-- 晚于天气服务写入属性时补刷一次
	task.defer(updateDisplay)
	task.delay(2, updateDisplay)
end

return GUI_Weather
