--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Framework = ReplicatedStorage:WaitForChild("ReplicatedCode"):WaitForChild("Framework")
local Janitor = require(Framework.Packages.Janitor)
local CloseButton = require(Framework.UI.CloseButton)

--[[
	Panel
	标准弹窗容器逻辑：统一 show / hide / 关闭按钮 / 简单进出场动画。

	用法示例（在具体 GUI 模块中）：

		local Panel = require(Framework.UI.Panel)

		function GUI_Setting:start()
			self:bindScreenGui() -- StarterGui 中需有同名 GUI_Setting ScreenGui

			local root = self.Gui.Root :: Frame
			local closeBtn = root.TitleBox.CloseButton :: GuiButton

			self._panel = Panel.new({
				frame = root,
				closeButton = closeBtn,
				onClose = function()
					-- 交给 UILayerHandler 来真正隐藏
					-- UILayerHandler.hide(UILayerId.GUI_Setting)
				end,
			})
		end
]]

export type PanelConfig = {
	frame: Frame,
	closeButton: GuiButton?,
	onClose: (() -> ())?,
	tweenIn: boolean?,
	tweenOut: boolean?,
}

export type PanelClass = {
	show: (self: PanelClass) -> (),
	hide: (self: PanelClass) -> (),
	setEnabled: (self: PanelClass, enabled: boolean) -> (),
	destroy: (self: PanelClass) -> (),
}

local DEFAULT_TWEEN_INFO = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local Panel = {}
Panel.__index = Panel

function Panel.new(config: PanelConfig): PanelClass
	local frame = config.frame
	local closeButtonInstance = config.closeButton

	local self = setmetatable({
		_frame = frame,
		_onClose = config.onClose,
		_janitor = Janitor.new(),
		_tweenIn = config.tweenIn ~= false,
		_tweenOut = config.tweenOut ~= false,
		_closeButton = nil :: CloseButton.ClassType?,
	}, Panel) :: PanelClass

	-- 初始化时默认隐藏或保持 prefab 默认状态，由上层决定

	-- 绑定关闭按钮（如果提供）
	if closeButtonInstance then
		self._closeButton = CloseButton.new(closeButtonInstance)
		self._janitor:Add(function()
			self._closeButton:destroy()
		end, "DestroyCloseButton")

		self._closeButton:getButton().activated:Connect(function()
			if self._onClose then
				self._onClose()
			else
				self:hide()
			end
		end)
	end

	return (self :: any) :: PanelClass
end

function Panel:setEnabled(enabled: boolean)
	self._frame.Visible = enabled
end

function Panel:show()
	if self._tweenIn then
		(self._frame :: GuiObject).Visible = true
		(self._frame :: GuiObject).BackgroundTransparency = 1
		local tween = TweenService:Create(self._frame, DEFAULT_TWEEN_INFO, { BackgroundTransparency = 0 })
		tween:Play()
	else
		self._frame.Visible = true
	end
end

function Panel:hide()
	if self._tweenOut then
		local tween = TweenService:Create(self._frame, DEFAULT_TWEEN_INFO, { BackgroundTransparency = 1 })
		tween.Completed:Connect(function()
			self._frame.Visible = false
		end)
		tween:Play()
	else
		self._frame.Visible = false
	end
end

function Panel:destroy()
	self._janitor:Destroy()
end

return Panel

