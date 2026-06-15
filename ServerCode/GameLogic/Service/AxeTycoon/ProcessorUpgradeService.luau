--!strict

--[[
	处理机升级服务（服务端权威）。

	玩家触碰自己基地 TouchedButtons/Upgrade，花费 Cash 提升 processorUpgradeCount，
	从而增加 ProcessorUpgradeConfig.getRate 决定的每秒加工数量。
	Billboard：Tip 显示本次升级增益，Price 显示升级价格。
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local ReplicatedCode = ReplicatedStorage:WaitForChild("ReplicatedCode")
local ServerCode = ServerScriptService:WaitForChild("ServerCode")

local safePlayerAdded = require(ReplicatedCode.Framework.Utility.Player.SafePlayerAdded)
local formatInteger = require(ReplicatedCode.Framework.Utility.Format.FormatInteger)
local ShowUnitNum = require(ReplicatedCode.Framework.UI.ShowUnitNum)
local Network = require(ReplicatedCode.Framework.Core.Network)
local RemoteEventKey = require(ReplicatedCode.GameLogic.SharedConstants.Keys.RemoteEventKey)
local BaseConfig = require(ReplicatedCode.GameLogic.Shared.Configs.BaseConfig)
local ProcessorUpgradeConfig = require(ReplicatedCode.GameLogic.Shared.Configs.ProcessorUpgradeConfig)
local CashKey = require(ReplicatedCode.GameLogic.SharedConstants.Keys.CashKey)
local PlayerDataKey = require(ReplicatedCode.GameLogic.SharedConstants.Keys.PlayerDataKey)
local TransactionEnum = require(ReplicatedCode.GameLogic.SharedConstants.Enums.TransactionEnum)
local PlayerDataServer = require(ServerCode.Framework.DataStore.PlayerData.PlayerDataServer)
local PlayerService = require(ServerCode.GameLogic.Service.Sync.PlayerService)
local BaseAssignmentService = require(ServerCode.GameLogic.Service.AxeTycoon.BaseAssignmentService)
local DebouncedPlayerSave = require(ServerCode.GameLogic.Modules.AxeTycoon.DebouncedPlayerSave)
local ProcessorBaseAttributes = require(ServerCode.GameLogic.Modules.AxeTycoon.ProcessorBaseAttributes)

local UPGRADE_BUTTON_NAME = "Upgrade"

local ProcessorUpgradeService = {}

local lastTouchAt: { [BasePart]: number } = {}
local started = false

local function getUpgradeCount(axeTycoon: any): number
	if type(axeTycoon) ~= "table" then
		return 0
	end
	return math.max(0, math.floor(tonumber(axeTycoon.processorUpgradeCount) or 0))
end

local function formatBoost(boost: number): string
	if boost == math.floor(boost) then
		return formatInteger(boost)
	end
	return string.format("%.1f", boost)
end

local function formatUpgradePrice(cost: number): string
	return "$" .. ShowUnitNum(cost)
end

-- 刷新玩家基地 Upgrade 按钮 Billboard（增益提示 + 价格）
function ProcessorUpgradeService.updateBillboard(player: Player)
	local base = BaseAssignmentService.getBase(player)
	if not base then
		return
	end

	local buttons = base:FindFirstChild("Touch_Collection")
	local part = buttons and buttons:FindFirstChild(UPGRADE_BUTTON_NAME)
	local billboard = part and part:FindFirstChild("Billboard")
	local main = billboard and billboard:FindFirstChild("Main")
	if not main then
		return
	end

	local tipLabel = main:FindFirstChild("Tip")
	local priceLabel = main:FindFirstChild("Price")

	local axeTycoon = PlayerDataServer.getValue(player, PlayerDataKey.AxeTycoon)
	local upgradeCount = getUpgradeCount(axeTycoon)
	local boost = ProcessorUpgradeConfig.getBoost(upgradeCount)
	local cost = ProcessorUpgradeConfig.getUpgradeCost(upgradeCount)

	if tipLabel and tipLabel:IsA("TextLabel") then
		tipLabel.Text = string.format("+%s per second", formatBoost(boost))
	end
	if priceLabel and priceLabel:IsA("TextLabel") then
		priceLabel.Text = formatUpgradePrice(cost)
	end
end

-- 花费 Cash 升级处理机每秒加工数量。成功返回 true。
function ProcessorUpgradeService.upgrade(player: Player): boolean
	local axeData = PlayerDataServer.getValue(player, PlayerDataKey.AxeTycoon)
	if type(axeData) ~= "table" then
		return false
	end

	local upgradeCount = getUpgradeCount(axeData)
	local cost = ProcessorUpgradeConfig.getUpgradeCost(upgradeCount)
	if cost <= 0 then
		return false
	end

	if not PlayerService.reduceCash(player, CashKey.Cash, cost, TransactionEnum.Gameplay, "processor_upgrade") then
		return false
	end

	PlayerDataServer.updateValue(player, PlayerDataKey.AxeTycoon, function(data)
		data = if type(data) == "table" then data else {}
		local current = getUpgradeCount(data)
		data.processorUpgradeCount = current + 1
		return data
	end)

	ProcessorUpgradeService.updateBillboard(player)
	-- 升级影响每秒速率，墙面 Info 文本由基地 Attribute 驱动，需同步
	local base = BaseAssignmentService.getBase(player)
	if base then
		ProcessorBaseAttributes.apply(base, PlayerDataServer.getValue(player, PlayerDataKey.AxeTycoon))
	end
	DebouncedPlayerSave.schedule(player)
	return true
end

local function onUpgradeTouched(part: BasePart, otherPart: BasePart)
	local character = otherPart.Parent
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end

	local base = BaseAssignmentService.getBase(player)
	if not base or not part:IsDescendantOf(base) then
		return
	end

	local now = os.clock()
	local last = lastTouchAt[part]
	if last and now - last < BaseConfig.BUTTON_DEBOUNCE then
		return
	end
	lastTouchAt[part] = now

	-- 仅业务成功才通知客户端在按钮处播放粒子特效
	if ProcessorUpgradeService.upgrade(player) then
		Network.fireClient(RemoteEventKey.TouchButtonVFX, player, part.Name)
	end
end

local function bindBase(base: Folder)
	local buttons = base:FindFirstChild("Touch_Collection")
	local upgradePart = buttons and buttons:FindFirstChild(UPGRADE_BUTTON_NAME)
	if upgradePart and upgradePart:IsA("BasePart") then
		local capturedPart = upgradePart :: BasePart
		capturedPart.Touched:Connect(function(otherPart)
			onUpgradeTouched(capturedPart, otherPart)
		end)
	end
end

function ProcessorUpgradeService.start()
	if started then
		return
	end
	started = true

	local world = Workspace:FindFirstChild("World")
	if world then
		for _, child in world:GetChildren() do
			if child:IsA("Folder") and string.match(child.Name, "^Base_%d+$") then
				bindBase(child)
			end
		end
	else
		warn("[ProcessorUpgradeService] 未找到 Workspace.World，Upgrade 触碰未绑定")
	end

	safePlayerAdded(function(player)
		PlayerDataServer.waitForDataLoadAsync(player)
		local deadline = os.clock() + 10
		while not BaseAssignmentService.getBase(player) and os.clock() < deadline do
			task.wait(0.2)
		end
		ProcessorUpgradeService.updateBillboard(player)
	end)
end

return ProcessorUpgradeService
