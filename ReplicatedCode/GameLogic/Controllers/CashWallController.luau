--!strict

--[[
	处理机墙面 SurfaceGui 控制器（纯客户端，全员渲染）。

	服务端把 processorStock / processorUpgradeCount 写在各 Base_* 折叠的 Attribute 上
	（见 ProcessorBaseAttributes），本控制器监听 Workspace.World 下所有基地的属性变化，
	刷新各自 CashWall/Wall/SurfaceGui 下的：
	- Wood：待加工库存，无库存（或基地无主）时显示 "No wood"
	- Info：当前每秒处理效率，格式 "{rate} per second"

	这样无论看谁的基地，墙面文本对所有玩家都一致。
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Framework = ReplicatedStorage.ReplicatedCode.Framework
local GameLogic = ReplicatedStorage.ReplicatedCode.GameLogic

local ShowUnitNum = require(Framework.UI.ShowUnitNum)
local ProcessorUpgradeConfig = require(GameLogic.Shared.Configs.ProcessorUpgradeConfig)
local WoodConfig = require(GameLogic.Shared.Configs.WoodConfig)
local AttributeEnum = require(GameLogic.Shared.Enums.AttributeEnum)

local NO_WOOD_TEXT = "No item"
local RESOLVE_TIMEOUT = 30

local CashWallController = {
	Name = "CashWallController",
	_started = false,
}

local boundBases: { [Folder]: boolean } = {}

local function formatRate(rate: number): string
	if rate == math.floor(rate) then
		return ShowUnitNum(rate)
	end
	return string.format("%.1f", rate)
end

local function formatProcessorStock(stock: number): string
	if stock <= 0 then
		return NO_WOOD_TEXT
	end
	return WoodConfig.formatWoodQuantity(stock)
end

local function formatInfoText(upgradeCount: number): string
	local rate = ProcessorUpgradeConfig.getRate(upgradeCount)
	return string.format("%s per second", formatRate(rate))
end

-- 带超时的 WaitForChild 链式查找
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

local FRAME_PATH = { "CashWall", "Wall", "SurfaceGui", "Frame" }

-- 即时查找（用于 DescendantAdded 重试，避免每次触发都阻塞等待）
local function findLabels(base: Folder): (TextLabel?, TextLabel?)
	local cashWall = base:WaitForChild("Touch_Collection"):WaitForChild("Machine_Upgrader")
	local wall = cashWall and cashWall:FindFirstChild("Wall")
	local surfaceGui = wall and wall:FindFirstChild("SurfaceGui")
	local frame = surfaceGui and surfaceGui:FindFirstChild("Frame")
	if not frame then
		return nil, nil
	end

	local woodLabel = frame:FindFirstChild("Wood")
	local infoLabel = frame:FindFirstChild("Info")
	if woodLabel and woodLabel:IsA("TextLabel") and infoLabel and infoLabel:IsA("TextLabel") then
		return woodLabel, infoLabel
	end
	return nil, nil
end

-- 首次绑定：逐级等待 CashWall 子树复制完成
local function waitForLabels(base: Folder): (TextLabel?, TextLabel?)
	local frame = waitForDescendant(base, FRAME_PATH, RESOLVE_TIMEOUT)
	if not frame then
		return nil, nil
	end

	local woodLabel = frame:WaitForChild("Wood", RESOLVE_TIMEOUT)
	local infoLabel = frame:WaitForChild("Info", RESOLVE_TIMEOUT)
	if woodLabel and woodLabel:IsA("TextLabel") and infoLabel and infoLabel:IsA("TextLabel") then
		return woodLabel, infoLabel
	end
	return nil, nil
end

-- 绑定单个基地：解析标签 + 监听处理机属性变化刷新（基地为池化常驻折叠，连接无需回收）
local function bindBase(base: Folder)
	if boundBases[base] then
		return
	end

	local function attach(woodLabel: TextLabel, infoLabel: TextLabel)
		if boundBases[base] then
			return
		end
		boundBases[base] = true

		local function refresh()
			-- 基地无主时属性为 nil，回落为 0 -> 显示 "No wood" 与基础速率
			local stock = tonumber(base:GetAttribute(AttributeEnum.ProcessorStock)) or 0
			local upgradeCount = tonumber(base:GetAttribute(AttributeEnum.ProcessorUpgradeCount)) or 0
			woodLabel.Text = formatProcessorStock(stock)
			infoLabel.Text = formatInfoText(upgradeCount)
		end

		base:GetAttributeChangedSignal(AttributeEnum.ProcessorStock):Connect(refresh)
		base:GetAttributeChangedSignal(AttributeEnum.ProcessorUpgradeCount):Connect(refresh)
		refresh()
	end

	local function tryBind(): boolean
		local woodLabel, infoLabel = findLabels(base)
		if woodLabel and infoLabel then
			attach(woodLabel, infoLabel)
			return true
		end
		return false
	end

	local woodLabel, infoLabel = waitForLabels(base)
	if woodLabel and infoLabel then
		attach(woodLabel, infoLabel)
		return
	end

	-- CashWall 子树可能晚于基地文件夹流式到达，监听后代复制后重试
	local connection: RBXScriptConnection
	connection = base.DescendantAdded:Connect(function()
		if tryBind() then
			connection:Disconnect()
		end
	end)
	task.delay(RESOLVE_TIMEOUT, function()
		if connection.Connected then
			connection:Disconnect()
		end
		if not boundBases[base] and not tryBind() then
			warn(
				string.format(
					"[CashWallController] %s 未找到 CashWall/Wall/SurfaceGui/Frame 下的 Wood/Info TextLabel",
					base.Name
				)
			)
		end
	end)
end

local function isBaseFolder(child: Instance): boolean
	return child:IsA("Folder") and string.match(child.Name, "^Base_%d+$") ~= nil
end

function CashWallController:init()
	if self._started then
		return
	end
	self._started = true

	task.spawn(function()
		local world = Workspace:WaitForChild("World", RESOLVE_TIMEOUT)
		if not world then
			warn("[CashWallController] 未找到 Workspace.World，墙面未绑定")
			return
		end

		for _, child in world:GetChildren() do
			if isBaseFolder(child) then
				task.spawn(bindBase, child :: Folder)
			end
		end
		world.ChildAdded:Connect(function(child)
			if isBaseFolder(child) then
				task.spawn(bindBase, child :: Folder)
			end
		end)
	end)
end

return CashWallController
