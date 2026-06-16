--!strict

--[[
	GUI_Notify
	全局通知 toast（提示 UI）的统一消费端。

	消费两类通知来源：
	  · 客户端本地：NetSignals.getSignal(TriggerSignalCategory.Client.notify):Fire(message, category, richText?)
	  · 服务端推送：Network.fireClient(RemoteEventKey.Unreliable_ServerNotify, player, message, category, richText?)

	UI 复用 HUD 预制体内 MidBottom.Notify 下的 Type1/2/3 模板（运行时由 HUD 克隆进 PlayerGui）。
	Notify 容器自带 UIListLayout，克隆的 toast 会自动堆叠；模板本身 Visible=false 仅作样板。

	类型 → 模板映射（按模板渐变色）：
	  · NotifyCategory.Error   → Type1（红）
	  · NotifyCategory.Warn    → Type2（黄）
	  · NotifyCategory.Success → Type3（绿）

	说明：本模块由 UISetup 在 UILoaded 之前提前调用 listen（命中 EarlyListen 回退名 "GUI_Notify"），
	避免开局服务端 toast 被 UnreliableRemoteEvent 丢弃。
--]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local RC = ReplicatedStorage:WaitForChild("ReplicatedCode")

local Network               = require(RC.Framework.Core.Network)
local NetSignals            = require(RC.Framework.Core.Network.NetSignals)
local RemoteEventKey        = require(RC.GameLogic.SharedConstants.Keys.RemoteEventKey)
local TriggerSignalCategory = require(RC.GameLogic.SharedConstants.Categories.TriggerSignalCategory)
local NotifyCategory        = require(RC.GameLogic.SharedConstants.Categories.NotifyCategory)

local player    = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() :: Player
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local GUI_Notify = { Name = "GUI_Notify" }

-- toast 停留时间（秒）与同屏最大数量（超出移除最旧）
local DISPLAY_SECONDS = 3
local MAX_ACTIVE      = 6

local TYPE_BY_CATEGORY: { [string]: string } = {
	[NotifyCategory.Error]   = "Type1",
	[NotifyCategory.Warn]    = "Type2",
	[NotifyCategory.Success] = "Type3",
}
local DEFAULT_TYPE = "Type2"

local _container: Instance? = nil
local _templates: { [string]: ImageLabel } = {}
local _active: { Instance } = {}

local function tween(
	obj: Instance,
	time: number,
	props: { [string]: any },
	style: Enum.EasingStyle?,
	dir: Enum.EasingDirection?
): Tween
	local info = TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out)
	local t = TweenService:Create(obj, info, props)
	t:Play()
	return t
end

-- 弹出一条 toast
local function show(message: string, category: string?, richText: boolean?)
	if not _container or message == nil or message == "" then
		return
	end

	local typeName = (category and TYPE_BY_CATEGORY[category]) or DEFAULT_TYPE
	local template = _templates[typeName] or _templates[DEFAULT_TYPE]
	if not template then
		return
	end

	local notify = template:Clone()
	local warnText = notify:FindFirstChild("WarnText") :: TextLabel?
	if warnText then
		warnText.RichText = richText == true
		warnText.Text = message
	end
	notify.Visible = true
	notify.Parent = _container

	table.insert(_active, notify)
	-- 超量裁剪：移除最旧
	while #_active > MAX_ACTIVE do
		local oldest = table.remove(_active, 1)
		if oldest then
			oldest:Destroy()
		end
	end

	local uiScale = notify:FindFirstChild("UIScale") :: UIScale?
	local originalPos = notify.Position

	task.spawn(function()
		-- 进场（快速脉冲）
		if uiScale then
			uiScale.Scale = 0.7
			tween(uiScale, 0.12, { Scale = 1.15 }, Enum.EasingStyle.Back).Completed:Wait()
			tween(uiScale, 0.08, { Scale = 1 })
		end

		task.wait(DISPLAY_SECONDS)
		if not notify.Parent then
			return
		end

		-- 退场（上移 + 收缩消失）
		local upPos = originalPos - UDim2.new(0, 0, 0.05, 0)
		tween(notify, 0.15, { Position = upPos })
		if uiScale then
			tween(uiScale, 0.15, { Scale = 0.85 })
		end
		task.wait(0.15)

		tween(notify, 0.15, { Position = originalPos })
		if uiScale then
			tween(uiScale, 0.15, { Scale = 0 })
		end
		task.wait(0.15)

		local idx = table.find(_active, notify)
		if idx then
			table.remove(_active, idx)
		end
		notify:Destroy()
	end)
end

-- 供其它模块直接调用（等价于 Fire Client.notify 信号）
GUI_Notify.show = show

function GUI_Notify:init()
	local hud = playerGui:WaitForChild("HUD") :: ScreenGui
	local container = hud:WaitForChild("MidBottom"):WaitForChild("Notify")
	_container = container

	for _, typeName in ipairs({ "Type1", "Type2", "Type3" }) do
		local tpl = container:FindFirstChild(typeName)
		if tpl and tpl:IsA("ImageLabel") then
			tpl.Visible = false
			_templates[typeName] = tpl
		end
	end
end

function GUI_Notify:listen()
	-- 客户端本地通知信号
	NetSignals.getSignal(TriggerSignalCategory.Client.notify).Event:Connect(
		function(message: string, category: string?, richText: boolean?)
			show(message, category, richText)
		end
	)

	-- 服务端推送（UnreliableRemoteEvent）
	Network.connectEvent(
		RemoteEventKey.Unreliable_ServerNotify,
		function(message: string, category: string?, richText: boolean?)
			show(message, category, richText)
		end
	)
end

return GUI_Notify
