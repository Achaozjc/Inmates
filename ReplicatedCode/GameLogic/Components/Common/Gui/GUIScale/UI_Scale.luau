--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local GUIScale = require(script.Parent)

local getViewportScale = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.UI.GetViewportScale)
local AttributeEnum = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Enums.AttributeEnum)
local SettingEnum = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Enums.SettingEnum)

local UI_Scale = setmetatable({}, { __index = GUIScale })
UI_Scale.__index = UI_Scale

export type ClassType = GUIScale.ClassType & {}

-- 读取玩家 uiScale 设置对应的乘数（1/2/3 → 对应 UI_SCALE_OPTIONS）
local function getUserScaleMultiplier(): number
	local localPlayer = Players.LocalPlayer
	if not localPlayer then
		return 1
	end
	local idx = localPlayer:GetAttribute(AttributeEnum.Setting.uiScale)
	if type(idx) ~= "number" then
		return 1
	end
	local options = SettingEnum.UI_SCALE_OPTIONS
	return options[math.clamp(math.round(idx), 1, #options)] or 1
end

function UI_Scale.new(instance: GuiObject): ClassType
	local self: any = GUIScale.new(instance)
	setmetatable(self, UI_Scale)

	self:setup()

	-- 监听玩家 uiScale 属性变化
	local localPlayer = Players.LocalPlayer
	if localPlayer then
		localPlayer:GetAttributeChangedSignal(AttributeEnum.Setting.uiScale):Connect(function()
			self:scale()
		end)
	end

	return self
end

function UI_Scale.scale(self: ClassType)
	local userMul = getUserScaleMultiplier()

	if self._factor then
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local viewportSize = camera.ViewportSize
		local minScreenSize = math.min(viewportSize.X, viewportSize.Y)

		local isSmallScreen = minScreenSize < 650
		self._instance.Scale = (if isSmallScreen then self._factor else 1) * userMul
	else
		local minScale = getViewportScale()
		self._instance.Scale = minScale * userMul
	end
end

return UI_Scale

