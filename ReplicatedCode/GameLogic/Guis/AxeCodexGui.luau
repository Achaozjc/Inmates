--!strict

--[[
	斧子图鉴面板（客户端）。

	每行 5 格共 24 格（约 5 行，可纵向滚动），按稀有度 1~24 排列。每格用 ModelViewport 显示对应斧子模型作为 icon：
	- 未解锁（未发现）：setLight(false) 让模型只呈现黑色轮廓（剪影）
	- 已解锁（已发现）：setLight(true) 显示清晰样貌
	icon 下方显示该稀有度名称（英文，按稀有度渐变着色）。

	解锁状态来自服务端持久化的 AxeTycoon.discoveredAxes（曾拥有过即永久记录）。

	本面板为 Menu 类型，默认隐藏。打开入口由外部触发（openGui 信号）：
		local NetSignals = require(Framework.Core.Network.NetSignals)
		local TriggerSignalCategory = require(GameLogic.SharedConstants.Categories.TriggerSignalCategory)
		NetSignals.getSignal(TriggerSignalCategory.Client.openGui):Fire(UILayerId.GUI_AxeCodex, true)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = ReplicatedStorage.ReplicatedCode.Framework
local GameLogic = ReplicatedStorage.ReplicatedCode.GameLogic

local GuiBase = require(Framework.UI.GuiBase)
local UILayerId = require(Framework.UI.UILayerId)
local UILayerType = require(Framework.UI.UILayerType)
local UILayerHandler = require(Framework.UI.UILayerHandler)
local ModelViewport = require(Framework.UI.ModelViewport)
local PlayerDataClient = require(Framework.DataStore.PlayerDataClient)
local AxeConfig = require(GameLogic.Shared.Configs.AxeConfig)
local AxeCategory = require(GameLogic.SharedConstants.Categories.AxeCategory)
local ColorEnum = require(GameLogic.Shared.Enums.ColorEnum)
local PlayerDataKey = require(GameLogic.SharedConstants.Keys.PlayerDataKey)

-- 图标模型在 Viewport 内的朝向（正面朝向）
local ICON_MODEL_ANGLE = CFrame.identity

local AxeCodexGui = GuiBase.new(UILayerId.GUI_AxeCodex, UILayerType.Menu)

-- 每格的运行时句柄：viewport + 当前是否已解锁（用于增量刷新）
type Entry = {
	category: string,
	viewport: ModelViewport.ClassType,
	unlocked: boolean,
}

local entries: { Entry } = {}

-- 解析斧子模型预制体（缺失高稀有度时回退最低级 "1"）
local function resolveAxePrefab(category: string): Model?
	local instances = ReplicatedStorage:FindFirstChild("Instances")
	local prefabs = instances and instances:FindFirstChild("Prefabs")
	local axeFolder = prefabs and prefabs:FindFirstChild("Axe")
	if not axeFolder then
		return nil
	end
	local prefab = axeFolder:FindFirstChild(category) or axeFolder:FindFirstChild("1")
	if prefab and prefab:IsA("Model") then
		return prefab
	end
	return nil
end

-- 读取已发现斧子 set
local function getDiscovered(): { [string]: boolean }
	local axeTycoon = PlayerDataClient.get(PlayerDataKey.AxeTycoon)
	if type(axeTycoon) ~= "table" or type(axeTycoon.discoveredAxes) ~= "table" then
		return {}
	end
	return axeTycoon.discoveredAxes
end

-- 按稀有度升序排列的 category 列表（"1".."24"）
local function getSortedCategories(): { string }
	local categories: { string } = {}
	for _, category in AxeCategory do
		categories[#categories + 1] = category
	end
	table.sort(categories, function(a, b)
		return (tonumber(a) or 0) < (tonumber(b) or 0)
	end)
	return categories
end

-- 按解锁状态刷新单格（已解锁=清晰，未解锁=黑色剪影）
local function applyUnlockState(entry: Entry, unlocked: boolean)
	entry.unlocked = unlocked
	entry.viewport:setLight(unlocked)
end

-- 依据最新数据刷新所有格的解锁状态（仅在状态变化时切换）
local function refreshUnlocks()
	local discovered = getDiscovered()
	for _, entry in entries do
		local unlocked = discovered[entry.category] == true
		if unlocked ~= entry.unlocked then
			applyUnlockState(entry, unlocked)
		end
	end
end

-- 构建 24 格
local function buildEntries(grid: ScrollingFrame, template: Frame)
	local discovered = getDiscovered()

	for index, category in getSortedCategories() do
		local info = AxeConfig.Axes[category]
		local rarity = if info then info.rarity else index
		local displayName = if info then string.upper(info.name) else ("TIER " .. tostring(rarity))

		local cell = template:Clone()
		cell.Name = "Axe_" .. category
		cell.LayoutOrder = rarity
		cell.Visible = true

		local nameLabel = cell:FindFirstChild("NameLabel")
		if nameLabel and nameLabel:IsA("TextLabel") then
			nameLabel.Text = displayName
			local gradient = nameLabel:FindFirstChildOfClass("UIGradient")
			local colorSequence = ColorEnum.Axe[rarity]
			if gradient and colorSequence then
				gradient.Color = colorSequence
			end
		end

		local iconHolder = cell:FindFirstChild("Icon")
		local prefab = resolveAxePrefab(category)
		if iconHolder and iconHolder:IsA("Frame") and prefab then
			local viewport = ModelViewport.new({
				model = prefab,
				fitVisibleParts = true,
				modelAngle = ICON_MODEL_ANGLE,
				zoom = 1,
				lookOffset = Vector3.new(0, 0, 0),
				size = UDim2.fromScale(1, 1),
			})
			viewport:setParent(iconHolder)

			local unlocked = discovered[category] == true
			local entry: Entry = {
				category = category,
				viewport = viewport,
				unlocked = unlocked,
			}
			applyUnlockState(entry, unlocked)
			entries[#entries + 1] = entry
		end

		cell.Parent = grid
	end
end

function AxeCodexGui:start()
	local gui = self:bindScreenGui()

	local frame = gui:WaitForChild("Frame") :: Frame
	local grid = frame:WaitForChild("Grid") :: ScrollingFrame
	local template = grid:WaitForChild("ItemTemplate") :: Frame
	template.Visible = false

	local closeButton = frame:WaitForChild("CloseButton") :: TextButton
	closeButton.Activated:Connect(function()
		UILayerHandler.hide(self.Name)
	end)

	buildEntries(grid, template)
end

function AxeCodexGui:listen()
	-- discoveredAxes 随 AxeTycoon 数据复制，解锁后实时刷新剪影/清晰状态
	PlayerDataClient.getUpdateSignal(PlayerDataKey.AxeTycoon):Connect(function()
		refreshUnlocks()
	end)
end

return AxeCodexGui
