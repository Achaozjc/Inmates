--!strict

--[[
	处理机服务（服务端权威）——「处理换钱」核心链路。

	1. deposit：玩家触碰自己基地 Storage，将背负木头卸入处理机；
	   存入量 = WoodConfig 加权价值 × 全服木料倍率后向上取整（仅入库时换算，如 3 Wood × 1.2 → 4），
	   写入 processorStock 后清空 carrying（背负全部卸下，按倍率折算入库量）。
	2. 每秒结算：按 ProcessorUpgradeConfig.getRate 从 processorStock 取出等量，
	   转入 Currency.PendingCash（1 库存单位 = 1 待收现金，与 WoodConfig.value 一致）。

	注：Upgrade 按钮的升级逻辑由 ProcessorUpgradeService 负责（唯一入口），本服务不再处理。
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local ReplicatedCode = ReplicatedStorage:WaitForChild("ReplicatedCode")
local ServerCode = ServerScriptService:WaitForChild("ServerCode")

local setInterval = require(ReplicatedCode.Framework.Utility.Time.SetInterval)
local ShowUnitNum = require(ReplicatedCode.Framework.UI.ShowUnitNum)
local Network = require(ReplicatedCode.Framework.Core.Network)
local RemoteEventKey = require(ReplicatedCode.GameLogic.SharedConstants.Keys.RemoteEventKey)
local NotifyCategory = require(ReplicatedCode.GameLogic.SharedConstants.Categories.NotifyCategory)
local BaseConfig = require(ReplicatedCode.GameLogic.Shared.Configs.BaseConfig)
local ProcessorUpgradeConfig = require(ReplicatedCode.GameLogic.Shared.Configs.ProcessorUpgradeConfig)
local WoodConfig = require(ReplicatedCode.GameLogic.Shared.Configs.WoodConfig)
local WoodMultiplierConfig = require(ReplicatedCode.GameLogic.Shared.Configs.WoodMultiplierConfig)
local GamepassConfig = require(ReplicatedCode.GameLogic.Shared.Configs.GamepassConfig)
local AttributeEnum = require(ReplicatedCode.GameLogic.Shared.Enums.AttributeEnum)
local CashKey = require(ReplicatedCode.GameLogic.SharedConstants.Keys.CashKey)
local PlayerDataKey = require(ReplicatedCode.GameLogic.SharedConstants.Keys.PlayerDataKey)
local TransactionEnum = require(ReplicatedCode.GameLogic.SharedConstants.Enums.TransactionEnum)
local PlayerDataServer = require(ServerCode.Framework.DataStore.PlayerData.PlayerDataServer)
local PlayerService = require(ServerCode.GameLogic.Service.Sync.PlayerService)
local BaseAssignmentService = require(ServerCode.GameLogic.Service.AxeTycoon.BaseAssignmentService)
local CollectMoneyService = require(ServerCode.GameLogic.Service.AxeTycoon.CollectMoneyService)
local DebouncedPlayerSave = require(ServerCode.GameLogic.Modules.AxeTycoon.DebouncedPlayerSave)
local ProcessorBaseAttributes = require(ServerCode.GameLogic.Modules.AxeTycoon.ProcessorBaseAttributes)
local WoodMultiplierService = require(ServerCode.GameLogic.Service.AxeTycoon.WoodMultiplierService)
local EnvironmentBuffHelper = require(ReplicatedCode.GameLogic.Shared.Weather.EnvironmentBuffHelper)

local STORAGE_BUTTON_NAME = "Storage"
local PROCESS_INTERVAL = 1

local ProcessorService = {}

local lastTouchAt: { [BasePart]: number } = {}
local started = false

-- 库存/速率数据变更后，把最新处理机状态写到基地 Attribute（复制给所有客户端渲染墙面）
local function syncBaseAttributes(player: Player)
	local base = BaseAssignmentService.getBase(player)
	if base then
		ProcessorBaseAttributes.apply(base, PlayerDataServer.getValue(player, PlayerDataKey.AxeTycoon))
	end
end

-- 单次存入的结果明细（供 UI 通知展示）
export type DepositInfo = {
	depositAmount: number,       -- 真实存入量（持有价值 × 倍率，含双倍木料通行证）
	woodValue: number,           -- 存入前背负的木头价值
	multiplier: number,          -- 本次存入的世界木料倍率
	bonus: number,               -- 相比存入前新增的量（depositAmount - woodValue，倍率 < 1 时为负）
	gamepassMultiplier: number,  -- 双倍木料通行证倍率（未拥有为 1）
}

-- 将背负木头卸入处理机（存入量已乘木料倍率）。成功返回存入明细，失败返回 nil。
function ProcessorService.deposit(player: Player): DepositInfo?
	local axeData = PlayerDataServer.getValue(player, PlayerDataKey.AxeTycoon)
	if type(axeData) ~= "table" then
		return nil
	end

	local carrying = if type(axeData.carrying) == "table" then axeData.carrying else {}
	local woodValue = WoodConfig.sumCarryingValue(carrying)
	if woodValue <= 0 then
		return nil
	end

	local multiplier = WoodMultiplierService.getMultiplier()
	local depositAmount = WoodMultiplierConfig.applyToDeposit(woodValue, multiplier)

	-- 双倍木料通行证：入库价值 ×2（拥有状态由 GamepassService 写入玩家属性）
	local gamepassMultiplier = 1
	if player:GetAttribute(AttributeEnum.GamepassDoubleWood) then
		gamepassMultiplier = GamepassConfig.DOUBLE_WOOD_MULTIPLIER
		depositAmount *= gamepassMultiplier
	end

	if depositAmount <= 0 then
		return nil
	end

	PlayerDataServer.updateValue(player, PlayerDataKey.AxeTycoon, function(data)
		data = if type(data) == "table" then data else {}
		data.carrying = {}
		data.processorStock = (tonumber(data.processorStock) or 0) + depositAmount
		return data
	end)
	syncBaseAttributes(player)
	DebouncedPlayerSave.schedule(player)
	return {
		depositAmount = depositAmount,
		woodValue = woodValue,
		multiplier = multiplier,
		bonus = depositAmount - woodValue,
		gamepassMultiplier = gamepassMultiplier,
	}
end

-- 付费功能：将处理机当前全部库存（processorStock）一次性转入 PendingCash。
-- 与每秒结算同样按 1 库存 = 1 待收现金换算，跳过排队等待，由玩家触碰 CollectMoney 领取。
-- 返回本次转入待收的金额（无库存时返回 0）。
function ProcessorService.instantProcessAll(player: Player): number
	local axeData = PlayerDataServer.getValue(player, PlayerDataKey.AxeTycoon)
	if type(axeData) ~= "table" then
		return 0
	end

	-- 在 updateValue 内读取并清零，避免与每秒结算产生竞态
	local processed = 0
	PlayerDataServer.updateValue(player, PlayerDataKey.AxeTycoon, function(data)
		data = if type(data) == "table" then data else {}
		processed = math.max(0, math.round(tonumber(data.processorStock) or 0))
		data.processorStock = 0
		return data
	end)
	syncBaseAttributes(player)

	if processed <= 0 then
		return 0
	end

	-- 库存按 1:1 转入待收；Cash 倍率在 CollectMoney 领取时统一结算
	PlayerService.addCash(player, CashKey.PendingCash, processed, TransactionEnum.Gameplay, "processor_instant")
	CollectMoneyService.updateBillboard(player)
	DebouncedPlayerSave.schedule(player)
	return processed
end

local function processPlayer(player: Player)
	local axeData = PlayerDataServer.getValue(player, PlayerDataKey.AxeTycoon)
	if type(axeData) ~= "table" then
		return
	end

	local stock = tonumber(axeData.processorStock) or 0
	if stock <= 0 then
		return
	end

	local upgradeCount = tonumber(axeData.processorUpgradeCount) or 0
	local rate = ProcessorUpgradeConfig.getRate(upgradeCount) * EnvironmentBuffHelper.getProcessorSpeedMultiplier()
	local processed = math.min(math.floor(rate), stock)
	if processed <= 0 then
		return
	end

	PlayerDataServer.updateValue(player, PlayerDataKey.AxeTycoon, function(data)
		data = if type(data) == "table" then data else {}
		local currentStock = tonumber(data.processorStock) or 0
		data.processorStock = math.max(0, currentStock - processed)
		return data
	end)
	syncBaseAttributes(player)

	-- 库存按 1:1 转入待收；Cash 倍率在 CollectMoney 领取时统一结算
	PlayerService.addCash(
		player,
		CashKey.PendingCash,
		processed,
		TransactionEnum.Gameplay,
		"processor"
	)
	CollectMoneyService.updateBillboard(player)
	DebouncedPlayerSave.schedule(player)
end

local function processAllPlayers()
	for _, player in Players:GetPlayers() do
		if PlayerDataServer.hasLoaded(player) then
			processPlayer(player)
		end
	end
end

-- 存入成功后向玩家推送 toast 通知：
-- Deposited {真实存入} ({+/-相比存入前新增}) Items [×{世界倍率}]!
-- 拥有双倍木料通行证时额外追加通行证倍率：... [×{世界倍率}] [x2]!
local function notifyDeposit(player: Player, info: DepositInfo)
	local depositStr = ShowUnitNum(info.depositAmount)
	local bonusStr = if info.bonus >= 0 then "+" .. ShowUnitNum(info.bonus) else ShowUnitNum(info.bonus)
	local multiplierStr = WoodMultiplierConfig.formatNotify(info.multiplier)
	-- 通行证倍率仅在拥有（> 1）时展示，如 [x2]
	local gamepassStr = if info.gamepassMultiplier > 1 then string.format(" [x%g]", info.gamepassMultiplier) else ""
	local message = string.format("Deposited %s (%s) Items [%s]%s!", depositStr, bonusStr, multiplierStr, gamepassStr)
	-- 倍率 ≥ 1（新增非负）走绿色 Success，倍率 < 1（折损）走黄色 Warn
	local category = if info.bonus >= 0 then NotifyCategory.Success else NotifyCategory.Warn
	Network.fireClient(RemoteEventKey.Unreliable_ServerNotify, player, message, category)
end

local function onStorageTouched(part: BasePart, otherPart: BasePart)
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

	-- 仅业务成功才通知客户端在按钮处播放粒子特效，并弹出存入 toast
	local info = ProcessorService.deposit(player)
	if info then
		Network.fireClient(RemoteEventKey.TouchButtonVFX, player, part.Name)
		notifyDeposit(player, info)
	end
end

local function bindBase(base: Folder)
	local buttons = base:FindFirstChild("Touch_Collection")
	local storagePart = buttons and buttons:FindFirstChild(STORAGE_BUTTON_NAME)
	if storagePart and storagePart:IsA("BasePart") then
		local capturedPart = storagePart :: BasePart
		capturedPart.Touched:Connect(function(otherPart)
			onStorageTouched(capturedPart, otherPart)
		end)
	end
end

function ProcessorService.start()
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
		warn("[ProcessorService] 未找到 Workspace.World，Storage 触碰未绑定")
	end

	setInterval(processAllPlayers, PROCESS_INTERVAL)
end

return ProcessorService
