--!strict

--[[
	全服木料倍率屏幕控制器（纯客户端显示）。

	职责：
	1. 玩家被分配到基地后，把预制体 ReplicatedStorage/Instances/Prefabs/Gui/WoodMultiplierGui
	   克隆到本地 PlayerGui，并把 Adornee 指向自己基地的 WoodMultiplier/Screen 部件。
	2. 刷新 Main 下的显示：
	   - Top.Value：当前倍率，如 "1.2x"
	   - Bar.Handle：右对齐固定，仅调整 Size.X.Scale 表示反向进度（0.5x ~ 1.5x）
	   - Bottom.CountDown：距离下次刷新秒数，如 "30s"

	状态来源：服务端写在 Workspace 上的属性（晚加入兜底）+ AxeTycoonSync 远程事件（实时推送）。

	说明：SurfaceGui 放在 PlayerGui 并设置 Adornee 后仅本地玩家可见，
	这样每个玩家只会在自己基地的屏幕上看到倍率界面。
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Framework = ReplicatedStorage.ReplicatedCode.Framework
local GameLogic = ReplicatedStorage.ReplicatedCode.GameLogic

local Network = require(Framework.Core.Network)
local AttributeEnum = require(GameLogic.Shared.Enums.AttributeEnum)
local WoodMultiplierConfig = require(GameLogic.Shared.Configs.WoodMultiplierConfig)
local RemoteEventKey = require(GameLogic.SharedConstants.Keys.RemoteEventKey)

local localPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() :: Player

local COUNTDOWN_INTERVAL = 1

local WoodMultiplierController = {
	Name = "WoodMultiplierController",
	_started = false,
	_gui = nil :: SurfaceGui?,
	_valueLabel = nil :: TextLabel?,
	_countDownLabel = nil :: TextLabel?,
	_handle = nil :: Frame?,
	_nextRefreshAt = 0,
	_countdownThread = nil :: thread?,
}

-- 扫描 Workspace.World 下所有 Base_*，返回 OwnerId 属性匹配指定 UserId 的基地
local function findBaseByOwner(userId: number): Folder?
	local world = Workspace:FindFirstChild("World")
	if not world then
		return nil
	end
	for _, child in world:GetChildren() do
		if child:IsA("Folder") and string.match(child.Name, "^Base_%d+$") then
			if child:GetAttribute(AttributeEnum.OwnerId) == userId then
				return child
			end
		end
	end
	return nil
end

-- 阻塞等待，直到本地玩家被分配到基地（服务端写好 OwnerId 后即可命中）
local function waitForMyBase(): Folder
	local base = findBaseByOwner(localPlayer.UserId)
	while not base do
		task.wait(0.1)
		base = findBaseByOwner(localPlayer.UserId)
	end
	return base
end

-- 带超时的 WaitForChild 链式查找：刚进服时实例可能尚未复制完成，需等待而非一次性查找
local function waitForDescendant(root: Instance, names: { string }, timeout: number): Instance?
	local current: Instance? = root
	for _, name in names do
		if not current then
			return nil
		end
		current = current:WaitForChild(name, timeout)
	end
	return current
end

-- 解析倍率屏幕 SurfaceGui 预制体（ReplicatedStorage.Instances.Prefabs.Gui.WoodMultiplierGui）
local function resolvePrefab(): SurfaceGui?
	local prefab = waitForDescendant(ReplicatedStorage, { "Instances", "Prefabs", "Gui", WoodMultiplierConfig.PREFAB_NAME }, 10)
	return if prefab and prefab:IsA("SurfaceGui") then prefab else nil
end

-- 从克隆出的 SurfaceGui 中解析三个动态元素
local function resolveElements(gui: SurfaceGui): (TextLabel?, TextLabel?, Frame?)
	local main = gui:FindFirstChild("Main")
	if not main then
		return nil, nil, nil
	end

	local top = main:FindFirstChild("Top")
	local bottom = main:FindFirstChild("Bottom")
	local bar = main:FindFirstChild("Bar")

	local valueLabel = top and top:FindFirstChild("Value")
	local countDownLabel = bottom and bottom:FindFirstChild("CountDown")
	local handle = bar and bar:FindFirstChild("Handle")

	if valueLabel and valueLabel:IsA("TextLabel")
		and countDownLabel and countDownLabel:IsA("TextLabel")
		and handle and handle:IsA("Frame") then
		return valueLabel, countDownLabel, handle
	end
	return nil, nil, nil
end

local function formatCountdown(seconds: number): string
	return string.format("%ds", math.max(0, math.ceil(seconds)))
end

function WoodMultiplierController:applyState(multiplier: number, nextRefreshAt: number)
	self._nextRefreshAt = nextRefreshAt

	local valueLabel = self._valueLabel
	local handle = self._handle
	if valueLabel then
		valueLabel.Text = WoodMultiplierConfig.formatDisplay(multiplier)
	end
	if handle then
		local sizeX = WoodMultiplierConfig.getHandleSizeX(multiplier)
		handle.Size = UDim2.new(sizeX, 0, handle.Size.Y.Scale, handle.Size.Y.Offset)
	end

	self:refreshCountdown()
end

function WoodMultiplierController:refreshCountdown()
	local label = self._countDownLabel
	if not label then
		return
	end

	local remaining = self._nextRefreshAt - Workspace:GetServerTimeNow()
	label.Text = formatCountdown(remaining)
end

-- 读 Workspace 属性兜底初始化（晚加入时远程事件可能已错过）
function WoodMultiplierController:readWorkspaceAttributes()
	local multiplier = Workspace:GetAttribute(WoodMultiplierConfig.ATTR_MULTIPLIER)
	local nextRefreshAt = Workspace:GetAttribute(WoodMultiplierConfig.ATTR_NEXT_REFRESH_AT)
	if type(multiplier) == "number" and type(nextRefreshAt) == "number" then
		self:applyState(multiplier, nextRefreshAt)
	end
end

function WoodMultiplierController:startCountdownLoop()
	if self._countdownThread then
		return
	end

	self._countdownThread = task.spawn(function()
		while self._started do
			self:refreshCountdown()
			task.wait(COUNTDOWN_INTERVAL)
		end
	end)
end

function WoodMultiplierController:init()
	if self._started then
		return
	end
	self._started = true

	task.spawn(function()
		local base = waitForMyBase()

		-- OwnerId 属性可能先于基地子对象复制到客户端，需用 WaitForChild 等待
		local screen = waitForDescendant(base, { "WoodMultiplier", "Screen" }, 10)
		if not (screen and screen:IsA("BasePart")) then
			warn("[WoodMultiplierController] 未找到基地 WoodMultiplier/Screen 部件：" .. base.Name)
			return
		end

		local prefab = resolvePrefab()
		if not prefab then
			warn("[WoodMultiplierController] 未找到预制体 ReplicatedStorage/Instances/Prefabs/Gui/" .. WoodMultiplierConfig.PREFAB_NAME)
			return
		end

		local gui = prefab:Clone()
		gui.Adornee = screen
		gui.Parent = localPlayer:WaitForChild("PlayerGui")
		self._gui = gui

		local valueLabel, countDownLabel, handle = resolveElements(gui)
		if not valueLabel or not countDownLabel or not handle then
			warn("[WoodMultiplierController] 预制体 UI 结构不完整")
			return
		end

		self._valueLabel = valueLabel
		self._countDownLabel = countDownLabel
		self._handle = handle

		self:readWorkspaceAttributes()
		self:startCountdownLoop()

		Workspace:GetAttributeChangedSignal(WoodMultiplierConfig.ATTR_MULTIPLIER):Connect(function()
			self:readWorkspaceAttributes()
		end)
		Workspace:GetAttributeChangedSignal(WoodMultiplierConfig.ATTR_NEXT_REFRESH_AT):Connect(function()
			self:readWorkspaceAttributes()
		end)
	end)

	Network.connectEvent(RemoteEventKey.AxeTycoonSync, function(payload)
		if type(payload) ~= "table" or payload.kind ~= "multiplier" then
			return
		end
		local multiplier = payload.multiplier
		local nextRefreshAt = payload.nextRefreshAt
		if type(multiplier) == "number" and type(nextRefreshAt) == "number" then
			self:applyState(multiplier, nextRefreshAt)
		end
	end, Network.t.table)
end

return WoodMultiplierController
