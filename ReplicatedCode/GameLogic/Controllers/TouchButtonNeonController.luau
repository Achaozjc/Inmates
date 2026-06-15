--!strict

--[[
	触碰按钮霓虹灯控制器（纯客户端视觉）。

	职责：根据本地玩家当前数据，实时刷新自己基地三个触碰按钮文件夹
	（Touch_Merge&Buy / Touch_Collection / Touch_Group）下各按钮模型
	（<ButtonName>_Model/ButtonTouch/Neon）的颜色，提示该按钮当前是否可触发：

	- BuyAxe_1/5/25/100：Cash 足够支付对应批量价 → 绿(98,163,98)，否则 灰(86,86,86)
	- Upgrade：Cash 足够支付升级价 → 绿，否则 灰
	- CollectMoney：存在待收 PendingCash → 绿，否则 灰
	- Merge：当前斧子可合成 → 橙(163,135,89)，否则 灰
	- Storage：不处理

	说明：颜色随 Currency（Cash/PendingCash）与 AxeTycoon（ownedAxeCount/
	processorUpgradeCount/axes）数据变化即时刷新；CollectMoney_Model / Upgrade_Model
	若尚未在场景中加入，按钮缺失则自动跳过。
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Framework = ReplicatedStorage.ReplicatedCode.Framework
local GameLogic = ReplicatedStorage.ReplicatedCode.GameLogic

local PlayerDataClient = require(Framework.DataStore.PlayerDataClient)
local AxePriceConfig = require(GameLogic.Shared.Configs.AxePriceConfig)
local ProcessorUpgradeConfig = require(GameLogic.Shared.Configs.ProcessorUpgradeConfig)
local AttributeEnum = require(GameLogic.Shared.Enums.AttributeEnum)
local CashKey = require(GameLogic.SharedConstants.Keys.CashKey)
local PlayerDataKey = require(GameLogic.SharedConstants.Keys.PlayerDataKey)

-- 合成所需的最少同稀有度数量（与服务端 AxeMergeLogic 一致）
local MERGE_INPUT_COUNT = 3

-- 触碰按钮已拆分到三个文件夹：BuyAxe_*/Merge 在 Touch_Merge&Buy，
-- CollectMoney/Upgrade/Storage 在 Touch_Collection，Group 在 Touch_Group。
-- 按钮 Neon 需跨这三个文件夹解析。
local BUTTON_FOLDER_NAMES = { "Touch_Merge&Buy", "Touch_Collection", "Touch_Group" }

local COLOR_ENABLED = Color3.fromRGB(98, 163, 98) -- 可触发（绿）
local COLOR_DISABLED = Color3.fromRGB(86, 86, 86) -- 不可触发（灰）
local COLOR_BUY_DISABLED = Color3.fromRGB(163, 98, 98) -- 购买斧子买不起（红）
local COLOR_MERGE = Color3.fromRGB(163, 135, 89) -- Merge 可触发（橙）

-- 刷新所需的玩家数据快照
type DataContext = {
	cash: number,
	pendingCash: number,
	ownedAxeCount: number,
	upgradeCount: number,
	mergeable: boolean,
}

-- 一条 Neon 与其颜色计算函数
type NeonEntry = {
	neon: BasePart,
	compute: (DataContext) -> Color3,
}

-- 按钮模型名与颜色计算规则（用于按模型解析对应 Neon）
type NeonConfig = {
	modelName: string,
	compute: (DataContext) -> Color3,
}

local localPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() :: Player

local TouchButtonNeonController = {
	Name = "TouchButtonNeonController",
	_started = false,
	_entries = {} :: { NeonEntry },
}

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

local function waitForMyBase(): Folder
	local base = findBaseByOwner(localPlayer.UserId)
	while not base do
		task.wait(0.1)
		base = findBaseByOwner(localPlayer.UserId)
	end
	return base
end

-- 在多个按钮文件夹中解析某按钮模型下的 Neon 部件。兼容两种结构：
-- <ModelName>/ButtonTouch/Neon 或 <ModelName>/Neon（Upgrade_Model 无 ButtonTouch 中间层），
-- 故递归查找模型下首个名为 Neon 的部件。
local function resolveNeon(buttonFolders: { Instance }, modelName: string): BasePart?
	for _, folder in buttonFolders do
		local model = folder:FindFirstChild(modelName)
		local neon = model and model:FindFirstChild("Neon", true)
		if neon and neon:IsA("BasePart") then
			return neon
		end
	end
	return nil
end

-- 是否存在任意可合成的稀有度（同 category 数量 ≥ 3）
local function computeMergeable(axes: any): boolean
	if type(axes) ~= "table" then
		return false
	end
	local counts: { [string]: number } = {}
	for _, category in pairs(axes) do
		if type(category) == "string" then
			local count = (counts[category] or 0) + 1
			if count >= MERGE_INPUT_COUNT then
				return true
			end
			counts[category] = count
		end
	end
	return false
end

-- 各按钮模型名与其颜色计算规则（Storage 不处理，故不在列）
local function buildConfigs(): { NeonConfig }
	local configs: { NeonConfig } = {}

	-- BuyAxe_N：Cash 足够支付对应批量价 → 绿，买不起 → 红
	for _, bundle in AxePriceConfig.Bundles do
		local capturedBundle = bundle
		configs[#configs + 1] = {
			modelName = "BuyAxe_" .. bundle .. "_Model",
			compute = function(ctx)
				local price = AxePriceConfig.getBundlePrice(ctx.ownedAxeCount, capturedBundle)
				return if ctx.cash >= price then COLOR_ENABLED else COLOR_BUY_DISABLED
			end,
		}
	end

	-- Merge：可合成 → 橙
	configs[#configs + 1] = {
		modelName = "Merge_Model",
		compute = function(ctx)
			return if ctx.mergeable then COLOR_MERGE else COLOR_DISABLED
		end,
	}

	-- CollectMoney：有待收金额 → 绿
	configs[#configs + 1] = {
		modelName = "CollectMoney_Model",
		compute = function(ctx)
			return if ctx.pendingCash > 0 then COLOR_ENABLED else COLOR_DISABLED
		end,
	}

	-- Upgrade：Cash 足够支付升级价 → 绿
	configs[#configs + 1] = {
		modelName = "Upgrade_Model",
		compute = function(ctx)
			local cost = ProcessorUpgradeConfig.getUpgradeCost(ctx.upgradeCount)
			return if ctx.cash >= cost then COLOR_ENABLED else COLOR_DISABLED
		end,
	}

	return configs
end

-- 从当前玩家数据构造刷新所需快照
local function readContext(): DataContext
	local currency = PlayerDataClient.get(PlayerDataKey.Currency)
	local cash, pendingCash = 0, 0
	if type(currency) == "table" then
		cash = math.floor(tonumber(currency[CashKey.Cash]) or 0)
		pendingCash = math.floor(tonumber(currency[CashKey.PendingCash]) or 0)
	end

	local axeTycoon = PlayerDataClient.get(PlayerDataKey.AxeTycoon)
	local ownedAxeCount, upgradeCount, mergeable = 0, 0, false
	if type(axeTycoon) == "table" then
		ownedAxeCount = tonumber(axeTycoon.ownedAxeCount) or 0
		upgradeCount = tonumber(axeTycoon.processorUpgradeCount) or 0
		mergeable = computeMergeable(axeTycoon.axes)
	end

	return {
		cash = cash,
		pendingCash = pendingCash,
		ownedAxeCount = ownedAxeCount,
		upgradeCount = upgradeCount,
		mergeable = mergeable,
	}
end

function TouchButtonNeonController:refresh()
	local entries = self._entries
	if #entries == 0 then
		return
	end
	local ctx = readContext()
	for _, entry in entries do
		if entry.neon.Parent then
			entry.neon.Color = entry.compute(ctx)
		end
	end
end

function TouchButtonNeonController:init()
	if self._started then
		return
	end
	self._started = true

	task.spawn(function()
		if not PlayerDataClient.hasLoaded() then
			PlayerDataClient.loaded:Wait()
		end

		local base = waitForMyBase()
		-- 收集三个按钮文件夹（缺失的跳过），按钮 Neon 跨文件夹解析
		local buttonFolders: { Instance } = {}
		for _, folderName in BUTTON_FOLDER_NAMES do
			local folder = base:WaitForChild(folderName, 30)
			if folder then
				table.insert(buttonFolders, folder)
			end
		end
		if #buttonFolders == 0 then
			warn("[TouchButtonNeonController] 未找到基地按钮文件夹：" .. table.concat(BUTTON_FOLDER_NAMES, "/"))
			return
		end

		-- 尚未解析到 Neon 的按钮配置（模型可能仍在复制/流式加载）
		local pending = buildConfigs()

		-- 尝试解析 pending 中已就绪的按钮：建 entry 并按当前数据立即上色。
		-- 返回是否已全部解析完毕。
		local function resolvePending(): boolean
			local ctx = readContext()
			for i = #pending, 1, -1 do
				local config = pending[i]
				local neon = resolveNeon(buttonFolders, config.modelName)
				if neon then
					local entry: NeonEntry = { neon = neon, compute = config.compute }
					table.insert(self._entries, entry)
					neon.Color = entry.compute(ctx) -- 解析即上色，避免保留默认色
					table.remove(pending, i)
				end
			end
			return #pending == 0
		end

		-- 首次解析；若仍有按钮模型未就绪，监听各文件夹后续复制到达再补，兜底超时停止监听
		if not resolvePending() then
			local connections: { RBXScriptConnection } = {}
			local function disconnectAll()
				for _, connection in connections do
					if connection.Connected then
						connection:Disconnect()
					end
				end
			end
			for _, folder in buttonFolders do
				table.insert(
					connections,
					folder.DescendantAdded:Connect(function()
						if resolvePending() then
							disconnectAll()
						end
					end)
				)
			end
			task.delay(30, disconnectAll)
		end

		-- Cash / PendingCash 变化与斧子数据变化时即时刷新
		PlayerDataClient.getUpdateSignal(PlayerDataKey.Currency):Connect(function()
			self:refresh()
		end)
		PlayerDataClient.getUpdateSignal(PlayerDataKey.AxeTycoon):Connect(function()
			self:refresh()
		end)
	end)
end

return TouchButtonNeonController
