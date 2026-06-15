--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Framework = ReplicatedStorage:WaitForChild("ReplicatedCode"):WaitForChild("Framework")
local UILayerHandler = require(Framework.UI.UILayerHandler)
local UILayerType = require(Framework.UI.UILayerType)
local UILayerId = require(Framework.UI.UILayerId)
local MenuTween = require(Framework.UI.MenuTween)
local BindStarterGui = require(Framework.Utility.UI.BindStarterGui)
local NetSignals = require(Framework.Core.Network.NetSignals)
local TriggerSignalCategory =
	require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.TriggerSignalCategory)

--[[
	GuiBase
	通用 GUI 基类（由 dingdong BaseGui 移植并适配 axe）。

	使用方式（示例）：

		[Studio] 在 StarterGui 下创建名为 GUI_Setting 的 ScreenGui 预制体。

		local GuiBase = require(Framework.UI.GuiBase)
		local GUI_Setting = GuiBase.new(UILayerId.GUI_Setting, UILayerType.Menu)

		function GUI_Setting:start()
			self:bindScreenGui()
			-- 缓存节点、绑定按钮...
		end

		function GUI_Setting:listen()
			-- 监听数据 / 网络事件...
		end

		return GUI_Setting

	说明：
	- ScreenGui 预制体放在 StarterGui，名称须与 layerId 一致。
	- Menu 类型会在显示时播放 Frame 的 MenuTween 动画。
	- openGui 信号（原 dingdong UITrigger）可远程打开/关闭本层。
	- HUD 类型注册后会自动 UILayerHandler.show。
]]

export type GuiBaseType = {
	Name: string,
	player: Player,
	Gui: ScreenGui?,
	switchSignal: BindableEvent?,
	_menuTween: MenuTween.ClassType?,
	setEnabled: (self: GuiBaseType, enabled: boolean) -> (),
	show: (self: GuiBaseType) -> (),
	hide: (self: GuiBaseType) -> (),
	bindScreenGui: (self: GuiBaseType, screenGuiName: string?) -> ScreenGui,
	_registerLayer: (self: GuiBaseType) -> (),
	start: (self: GuiBaseType) -> (),
	listen: (self: GuiBaseType) -> (),
	init: (self: GuiBaseType) -> (),
}

local GuiBase = {}
GuiBase.__index = GuiBase

local localPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait()

local function createMenuTween(screenGui: ScreenGui, layerType: UILayerType.EnumType): MenuTween.ClassType?
	if layerType ~= UILayerType.Menu then
		return nil
	end

	local baseFrame = screenGui:FindFirstChild("Frame")
	if baseFrame and baseFrame:IsA("Frame") then
		return MenuTween.new(baseFrame)
	end

	return nil
end

function GuiBase.new(layerId: UILayerId.EnumType, layerType: UILayerType.EnumType, stayVisibleWithMenus: { string }?): GuiBaseType
	local self = setmetatable({}, GuiBase) :: any

	self.Name = layerId
	self.player = localPlayer
	self.Gui = nil
	self.switchSignal = nil
	self._menuTween = nil
	self._layerId = layerId
	self._layerType = layerType
	self._stayVisibleWithMenus = stayVisibleWithMenus

	function self:setEnabled(enabled: boolean)
		if self.Gui then
			self.Gui.Enabled = enabled
		end
	end

	function self:show()
		self:setEnabled(true)
		if self._menuTween then
			self._menuTween:doTween()
		end
	end

	function self:hide()
		self:setEnabled(false)
	end

	function self:bindScreenGui(screenGuiName: string?): ScreenGui
		local name = screenGuiName or self.Name
		local gui = BindStarterGui.waitForScreenGui(name, self.player)
		self.Gui = gui
		return gui
	end

	function self:_registerLayer()
		local visibilityChanged = UILayerHandler.registerLayer(
			self._layerId,
			self._layerType,
			self,
			self._stayVisibleWithMenus
		)

		visibilityChanged:Connect(function(isVisible: boolean)
			if isVisible then
				self:show()
				if self.switchSignal then
					self.switchSignal:Fire(true)
				end
			else
				self:hide()
				if self.switchSignal then
					self.switchSignal:Fire(false)
				end
			end
		end)

		local openGuiSignal = NetSignals.getSignal(TriggerSignalCategory.Client.openGui)
		openGuiSignal.Event:Connect(function(key: string, show: boolean?)
			if key ~= self._layerId then
				return
			end
			if show == false then
				UILayerHandler.hide(self._layerId)
			else
				UILayerHandler.show(self._layerId)
			end
		end)

		if self._layerType == UILayerType.HeadsUpDisplay then
			UILayerHandler.show(self._layerId)
		end
	end

	function self:start()
		self:bindScreenGui()
	end

	function self:listen() end

	function self:init()
		self:start()

		if self.Gui then
			self._menuTween = createMenuTween(self.Gui, self._layerType)
		end

		self.switchSignal = Instance.new("BindableEvent")
		self:_registerLayer()
		self:listen()
	end

	return self :: GuiBaseType
end

return GuiBase
