--!strict

--[[
	群组奖励服务（服务端权威）。

	玩家触碰自己基地 TouchedButtons/Group 时：
		1. 校验冷却：距上次领取需满 GroupRewardConfig.COOLDOWN 秒（持久化 AxeTycoon.lastGroupRewardAt）。
		2. 校验群组：玩家须已加入游戏群组（GroupId），未加入则不发放。
		3. 发放奖励：奖励额 = max(PER_AXE × 拥有斧头数, MIN_REWARD)，入 Cash 后落库。

	Billboard.Main.CashAmount 显示当前可领取额，CountDown 倒计时由客户端依据玩家属性
	AttributeEnum.GroupRewardReadyAt（下次可领取 Unix 时间）渲染，发放后属性即时刷新。
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local ReplicatedCode = ReplicatedStorage:WaitForChild("ReplicatedCode")
local ServerCode = ServerScriptService:WaitForChild("ServerCode")

local safePlayerAdded = require(ReplicatedCode.Framework.Utility.Player.SafePlayerAdded)
local IsInGroup = require(ReplicatedCode.Framework.Utility.Player.IsInGroup)
local ShowUnitNum = require(ReplicatedCode.Framework.UI.ShowUnitNum)
local Network = require(ReplicatedCode.Framework.Core.Network)
local RemoteEventKey = require(ReplicatedCode.GameLogic.SharedConstants.Keys.RemoteEventKey)
local BaseConfig = require(ReplicatedCode.GameLogic.Shared.Configs.BaseConfig)
local GroupRewardConfig = require(ReplicatedCode.GameLogic.Shared.Configs.GroupRewardConfig)
local GroupId = require(ReplicatedCode.GameLogic.Shared.Misc.GroupId)
local AttributeEnum = require(ReplicatedCode.GameLogic.Shared.Enums.AttributeEnum)
local CashKey = require(ReplicatedCode.GameLogic.SharedConstants.Keys.CashKey)
local PlayerDataKey = require(ReplicatedCode.GameLogic.SharedConstants.Keys.PlayerDataKey)
local TransactionEnum = require(ReplicatedCode.GameLogic.SharedConstants.Enums.TransactionEnum)
local PlayerDataServer = require(ServerCode.Framework.DataStore.PlayerData.PlayerDataServer)
local PlayerService = require(ServerCode.GameLogic.Service.Sync.PlayerService)
local BaseAssignmentService = require(ServerCode.GameLogic.Service.AxeTycoon.BaseAssignmentService)
local DebouncedPlayerSave = require(ServerCode.GameLogic.Modules.AxeTycoon.DebouncedPlayerSave)

local GROUP_BUTTON_NAME = "Group"

local GroupRewardService = {}

local lastTouchAt: { [BasePart]: number } = {}
local started = false

-- 读取玩家斧头大亨数据（缺失返回空表）
local function getAxeData(player: Player): { [string]: any }
	local axeData = PlayerDataServer.getValue(player, PlayerDataKey.AxeTycoon)
	return if type(axeData) == "table" then axeData else {}
end

-- 玩家当前拥有斧头数（ownedAxeCount）
local function getOwnedAxeCount(player: Player): number
	return tonumber(getAxeData(player).ownedAxeCount) or 0
end

-- 上次领取群组奖励的 Unix 时间（0=从未领取）
local function getLastRewardAt(player: Player): number
	return tonumber(getAxeData(player).lastGroupRewardAt) or 0
end

-- 下次可领取的 Unix 时间（0=可立即领取）
local function getReadyAt(player: Player): number
	local last = getLastRewardAt(player)
	return if last > 0 then last + GroupRewardConfig.COOLDOWN else 0
end

-- 把下次可领取时间写入玩家属性，供客户端 Billboard 倒计时
function GroupRewardService.syncReadyAttribute(player: Player)
	player:SetAttribute(AttributeEnum.GroupRewardReadyAt, getReadyAt(player))
end

-- 刷新 Group 按钮 Billboard 上的可领取金额
function GroupRewardService.updateBillboard(player: Player)
	local base = BaseAssignmentService.getBase(player)
	if not base then
		return
	end

	local buttons = base:FindFirstChild("Touch_Group")
	local part = buttons and buttons:FindFirstChild(GROUP_BUTTON_NAME)
	local billboard = part and part:FindFirstChild("Billboard")
	local main = billboard and billboard:FindFirstChild("Main")
	local amountLabel = main and main:FindFirstChild("CashAmount")
	if amountLabel and amountLabel:IsA("TextLabel") then
		amountLabel.Text = "$" .. ShowUnitNum(GroupRewardConfig.getReward(getOwnedAxeCount(player)))
	end
end

-- 尝试领取群组奖励：冷却内或未加入群组则不发放。返回是否成功发放。
-- 未加入群组（且已过冷却）时，通知客户端弹出加群提示。
function GroupRewardService.claim(player: Player): boolean
	if os.time() < getReadyAt(player) then
		return false
	end

	if not IsInGroup(player, GroupId) then
		Network.fireClient(RemoteEventKey.GroupRewardPromptJoin, player)
		return false
	end

	local reward = GroupRewardConfig.getReward(getOwnedAxeCount(player))
	if reward <= 0 then
		return false
	end

	-- 落库领取时间（写入后冷却开始）
	PlayerDataServer.updateValue(player, PlayerDataKey.AxeTycoon, function(data)
		data = if type(data) == "table" then data else {}
		data.lastGroupRewardAt = os.time()
		return data
	end)

	PlayerService.addCash(player, CashKey.Cash, reward, TransactionEnum.Gameplay, "GroupReward")
	GroupRewardService.syncReadyAttribute(player)
	GroupRewardService.updateBillboard(player)
	DebouncedPlayerSave.schedule(player)
	return true
end

local function onGroupTouched(part: BasePart, otherPart: BasePart)
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

	-- 仅成功发放奖励才通知客户端在按钮处播放粒子特效
	if GroupRewardService.claim(player) then
		Network.fireClient(RemoteEventKey.TouchButtonVFX, player, part.Name)
	end
end

local function bindBase(base: Folder)
	local buttons = base:FindFirstChild("Touch_Group")
	local groupPart = buttons and buttons:FindFirstChild(GROUP_BUTTON_NAME)
	if groupPart and groupPart:IsA("BasePart") then
		local capturedPart = groupPart :: BasePart
		capturedPart.Touched:Connect(function(otherPart)
			onGroupTouched(capturedPart, otherPart)
		end)
	end
end

function GroupRewardService.start()
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
		warn("[GroupRewardService] 未找到 Workspace.World，Group 触碰未绑定")
	end

	safePlayerAdded(function(player)
		PlayerDataServer.waitForDataLoadAsync(player)
		local deadline = os.clock() + 10
		while not BaseAssignmentService.getBase(player) and os.clock() < deadline do
			task.wait(0.2)
		end
		GroupRewardService.syncReadyAttribute(player)
		GroupRewardService.updateBillboard(player)
	end)
end

return GroupRewardService
