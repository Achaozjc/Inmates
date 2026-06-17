--!strict

--[[
	收钱服务（服务端权威）。

	玩家触碰自己基地 TouchedButtons/CollectMoney，将 Currency.PendingCash 全额转入 Cash。
	Billboard.Main.Price 显示当前待收金额，收集后归零。
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local ReplicatedCode = ReplicatedStorage:WaitForChild("ReplicatedCode")
local ServerCode = ServerScriptService:WaitForChild("ServerCode")

local safePlayerAdded = require(ReplicatedCode.Framework.Utility.Player.SafePlayerAdded)
local ShowUnitNum = require(ReplicatedCode.Framework.UI.ShowUnitNum)
local Network = require(ReplicatedCode.Framework.Core.Network)
local RemoteEventKey = require(ReplicatedCode.GameLogic.SharedConstants.Keys.RemoteEventKey)
local BaseConfig = require(ReplicatedCode.GameLogic.Shared.Configs.BaseConfig)
local CashKey = require(ReplicatedCode.GameLogic.SharedConstants.Keys.CashKey)
local PlayerDataKey = require(ReplicatedCode.GameLogic.SharedConstants.Keys.PlayerDataKey)
local TransactionEnum = require(ReplicatedCode.GameLogic.SharedConstants.Enums.TransactionEnum)
local PlayerDataServer = require(ServerCode.Framework.DataStore.PlayerData.PlayerDataServer)
local PlayerService = require(ServerCode.GameLogic.Service.Sync.PlayerService)
local BaseAssignmentService = require(ServerCode.GameLogic.Service.AxeTycoon.BaseAssignmentService)
local DebouncedPlayerSave = require(ServerCode.GameLogic.Modules.AxeTycoon.DebouncedPlayerSave)
local CashMultiplierService = require(ServerCode.GameLogic.Service.AxeTycoon.CashMultiplierService)

local COLLECT_BUTTON_NAME = "CollectMoney"

local CollectMoneyService = {}

local lastTouchAt: { [BasePart]: number } = {}
local started = false

local function getPendingCash(currency: any): number
	if type(currency) ~= "table" then
		return 0
	end
	return tonumber(currency[CashKey.PendingCash]) or 0
end

local function formatPendingPrice(pending: number): string
	return "$" .. ShowUnitNum(pending)
end

-- 刷新玩家基地 CollectMoney 按钮 Billboard 上的待收金额
function CollectMoneyService.updateBillboard(player: Player)
	local base = BaseAssignmentService.getBase(player)
	if not base then
		return
	end

	local buttons = base:FindFirstChild("Touch_Collection")
	local part = buttons and buttons:FindFirstChild(COLLECT_BUTTON_NAME)
	local billboard = part and part:FindFirstChild("Billboard")
	local main = billboard and billboard:FindFirstChild("Main")
	local priceLabel = main and main:FindFirstChild("Price")
	if priceLabel and priceLabel:IsA("TextLabel") then
		local currency = PlayerDataServer.getValue(player, PlayerDataKey.Currency)
		priceLabel.Text = formatPendingPrice(getPendingCash(currency))
	end
end

-- 将 PendingCash 全额转入 Cash。成功返回 true。
function CollectMoneyService.collect(player: Player): boolean
	local currency = PlayerDataServer.getValue(player, PlayerDataKey.Currency)
	local pending = getPendingCash(currency)
	if pending <= 0 then
		return false
	end

	if not PlayerService.reduceCash(
		player,
		CashKey.PendingCash,
		pending,
		TransactionEnum.Gameplay,
		"collect"
	) then
		return false
	end

	-- Cash 倍率 + 好友同服加成在领取时统一结算（未购买/无好友均为 1）
	local payout = math.floor(
		pending * CashMultiplierService.getMultiplier(player) * PlayerService.getFriendBoostMultiplier(player)
	)
	PlayerService.addCash(player, CashKey.Cash, payout, TransactionEnum.Gameplay, "collect")
	CollectMoneyService.updateBillboard(player)
	DebouncedPlayerSave.schedule(player)
	return true
end

local function onCollectTouched(part: BasePart, otherPart: BasePart)
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
	if CollectMoneyService.collect(player) then
		Network.fireClient(RemoteEventKey.TouchButtonVFX, player, part.Name)
	end
end

local function bindBase(base: Folder)
	local buttons = base:FindFirstChild("Touch_Collection")
	local collectPart = buttons and buttons:FindFirstChild(COLLECT_BUTTON_NAME)
	if collectPart and collectPart:IsA("BasePart") then
		local capturedPart = collectPart :: BasePart
		capturedPart.Touched:Connect(function(otherPart)
			onCollectTouched(capturedPart, otherPart)
		end)
	end
end

function CollectMoneyService.start()
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
		warn("[CollectMoneyService] 未找到 Workspace.World，CollectMoney 触碰未绑定")
	end

	safePlayerAdded(function(player)
		PlayerDataServer.waitForDataLoadAsync(player)
		local deadline = os.clock() + 10
		while not BaseAssignmentService.getBase(player) and os.clock() < deadline do
			task.wait(0.2)
		end
		CollectMoneyService.updateBillboard(player)
	end)
end

return CollectMoneyService
