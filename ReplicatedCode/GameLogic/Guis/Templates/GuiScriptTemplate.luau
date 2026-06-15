--!strict
--[[
	=====================================================================
	GUI 脚本模版（由 dingdong ClientStart/Guis 模式移植）
	=====================================================================

	注意：本文件仅作复制参考，位于 Templates 子目录，不会被 UISetup 加载。

	使用步骤：
	  1. 复制本文件到 Guis/ 目录，重命名为 YourNameGui.luau（名称任意，如 ShopGui）。
	  2. 在 UILayerId.luau 中注册 layerId（StarterGui ScreenGui 名称须与 layerId 一致）。
	  3. 在 StarterGui 中按下方结构手动创建 ScreenGui（勿与脚本模版同名）。
	  4. 修改下方 LAYER_ID、layerType，并实现 start / listen。

	[StarterGui 预制体结构 — Menu 类型]
	  YourLayerId (ScreenGui)      ← 名称与 UILayerId 枚举一致，非脚本文件名
	    Frame (Frame)              ← MenuTween 动画根节点，居中
	      Top (Frame)
	        Title (TextLabel)      ← 英文标题
	        CloseButton (GuiButton)
	      Content (Frame)          ← 主内容区
	        ...

	[StarterGui 预制体结构 — HUD 类型]
	  YourLayerId (ScreenGui)
	    ...                        ← HUD 无强制 Frame 结构，注册后自动显示

	打开方式：
	  UILayerHandler.show(LAYER_ID)
	  UILayerHandler.hide(LAYER_ID)
	  NetSignals.getSignal(TriggerSignalCategory.Client.openGui):Fire(LAYER_ID)
	  NetSignals.getSignal(TriggerSignalCategory.Client.openGui):Fire(LAYER_ID, false)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = ReplicatedStorage.ReplicatedCode.Framework

local GuiBase = require(Framework.UI.GuiBase)
local UILayerId = require(Framework.UI.UILayerId)
local UILayerType = require(Framework.UI.UILayerType)
local UILayerHandler = require(Framework.UI.UILayerHandler)
local CloseButton = require(Framework.UI.CloseButton)
-- local Button = require(Framework.UI.Button)
-- local Network = require(Framework.Core.Network)
-- local PlayerDataClient = require(Framework.DataStore.PlayerDataClient)
-- local NetSignals = require(Framework.Core.Network.NetSignals)
-- local TriggerSignalCategory = require(GameLogic.SharedConstants.Categories.TriggerSignalCategory)

-- TODO: 改为你的 UILayerId，并确保 StarterGui 中有同名 ScreenGui
local LAYER_ID = UILayerId.GUI_Setting

-- TODO: Menu = 弹窗菜单；HeadsUpDisplay = 常驻 HUD
local YourNameGui = GuiBase.new(LAYER_ID, UILayerType.Menu)

function YourNameGui:start()
	self:bindScreenGui()

	local frame = self.Gui:WaitForChild("Frame") :: Frame
	local top = frame:WaitForChild("Top") :: Frame
	local closeButton = top:WaitForChild("CloseButton") :: GuiButton
	-- local content = frame:WaitForChild("Content") :: Frame

	CloseButton.new(closeButton)._button.activated:Connect(function()
		UILayerHandler.hide(self.Name)
	end)

	-- 示例：普通按钮
	-- local actionButton = content:WaitForChild("ActionButton") :: GuiButton
	-- Button.new(actionButton).activated:Connect(function()
	-- 	-- TODO: 按钮逻辑
	-- end)
end

function YourNameGui:listen()
	-- 示例：监听数据变化
	-- PlayerDataClient.updated:Connect(function(key: string)
	-- 	-- TODO: 根据 key 刷新 UI
	-- end)

	-- 示例：监听开关信号（显示/隐藏时）
	-- if self.switchSignal then
	-- 	self.switchSignal.Event:Connect(function(isVisible: boolean)
	-- 		-- TODO: isVisible 为 true 时刷新界面
	-- 	end)
	-- end

	-- 示例：监听 openGui 以外的自定义信号
	-- NetSignals.getSignal(TriggerSignalCategory.Client.openGui).Event:Connect(function(key: string, ...)
	-- 	if key ~= self.Name then
	-- 		return
	-- 	end
	-- 	-- TODO
	-- end)
end

return YourNameGui
