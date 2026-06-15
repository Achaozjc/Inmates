--!strict

--[[
	木头背负服务（服务端权威）。

	堆叠区有木头时，每秒检测基地下名为 TouchedStacking 的 Part 区域内
	是否站着基地主人，是则将堆叠区木头转入 PlayerData.AxeTycoon.carrying，
	一次背走全部、无背负上限；支持多种木种并存（见实现计划 §八）。

	堆叠区数据在 TycoonState（内存）；背负持久化在 PlayerData，掉线不丢。
	成功后广播 AxeTycoonSync { kind = "pickup" }，供客户端清理堆叠区视觉。
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local ReplicatedCode = ReplicatedStorage:WaitForChild("ReplicatedCode")
local ServerCode = ServerScriptService:WaitForChild("ServerCode")

local Network = require(ReplicatedCode.Framework.Core.Network)
local RemoteEventKey = require(ReplicatedCode.GameLogic.SharedConstants.Keys.RemoteEventKey)
local PlayerDataKey = require(ReplicatedCode.GameLogic.SharedConstants.Keys.PlayerDataKey)
local PlayerDataServer = require(ServerCode.Framework.DataStore.PlayerData.PlayerDataServer)
local BaseAssignmentService = require(ServerCode.GameLogic.Service.AxeTycoon.BaseAssignmentService)
local DebouncedPlayerSave = require(ServerCode.GameLogic.Modules.AxeTycoon.DebouncedPlayerSave)
local TycoonState = require(ServerCode.GameLogic.Modules.AxeTycoon.TycoonState)

local STACKING_PART_NAME = "TouchedStacking"
-- 区域检测间隔（秒）
local CHECK_INTERVAL = 0.25

local WoodCarryService = {}

local started = false
-- 缓存每个基地解析到的堆叠区 Part，避免每秒重复遍历层级
local stackingPartCache: { [Folder]: BasePart } = {}

local function mergeCarrying(target: { [string]: number }, taken: { [string]: number })
	for category, count in taken do
		target[category] = (target[category] or 0) + count
	end
end

-- 解析基地内的堆叠区 Part（优先 AxeMachine/TouchedStacking，缺失时在基地内递归查找）
local function resolveStackingPart(base: Folder): BasePart?
	local cached = stackingPartCache[base]
	if cached and cached:IsDescendantOf(base) then
		return cached
	end

	local axeMachine = base:FindFirstChild("InmateMachine")
	local stacking = axeMachine and axeMachine:FindFirstChild(STACKING_PART_NAME)
	if not (stacking and stacking:IsA("BasePart")) then
		local found = base:FindFirstChild(STACKING_PART_NAME, true)
		stacking = if found and found:IsA("BasePart") then found else nil
	end

	if stacking and stacking:IsA("BasePart") then
		stackingPartCache[base] = stacking
		return stacking
	end
	return nil
end

-- 将堆叠区木头全部背到身上（无背负上限）
-- silent 为 true 时（如自动收集通行证）不下发拾取明细，客户端不弹飘字
function WoodCarryService.pickup(player: Player, silent: boolean?)
	local groundTotal = TycoonState.getGroundTotal(player.UserId)
	if groundTotal <= 0 then
		return
	end

	local axeData = PlayerDataServer.getValue(player, PlayerDataKey.AxeTycoon)
	if type(axeData) ~= "table" then
		return
	end

	-- 不再受 CARRY_LIMIT 约束：一次背走堆叠区全部木头
	local taken = TycoonState.takeGroundWood(player.UserId, groundTotal)
	if next(taken) == nil then
		return
	end

	PlayerDataServer.updateValue(player, PlayerDataKey.AxeTycoon, function(data)
		data = if type(data) == "table" then data else {}
		local nextCarrying = if type(data.carrying) == "table" then data.carrying else {}
		mergeCarrying(nextCarrying, taken)
		data.carrying = nextCarrying
		return data
	end)
	DebouncedPlayerSave.schedule(player)

	local base = BaseAssignmentService.getBase(player)
	if base then
		-- 木堆表现只在基地主人客户端渲染（见 WoodProductionService），清除事件也只需发给主人
		Network.fireClient(RemoteEventKey.AxeTycoonSync, player, {
			kind = "pickup",
			base = base,
			-- 拾取明细（类别 → 件数），供客户端按稀有度弹出拾取飘字；静默拾取时不下发
			taken = if silent then nil else taken,
		})
	end
end

-- 判断角色是否在堆叠区 Part 的包围盒内
local function isCharacterInRegion(part: BasePart, character: Model): boolean
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Include
	overlapParams.FilterDescendantsInstances = { character }
	local parts = Workspace:GetPartBoundsInBox(part.CFrame, part.Size, overlapParams)
	return #parts > 0
end

-- 单个玩家的定时检测：有木头且主人站在堆叠区内则触发拾取
local function checkPlayer(player: Player)
	if TycoonState.getGroundTotal(player.UserId) <= 0 then
		return
	end

	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local base = BaseAssignmentService.getBase(player)
	if not base then
		return
	end
	local part = resolveStackingPart(base)
	if not part then
		return
	end

	if isCharacterInRegion(part, character) then
		WoodCarryService.pickup(player)
	end
end

function WoodCarryService.start()
	if started then
		return
	end
	started = true

	task.spawn(function()
		while true do
			task.wait(CHECK_INTERVAL)
			for _, player in Players:GetPlayers() do
				checkPlayer(player)
			end
		end
	end)
end

return WoodCarryService
