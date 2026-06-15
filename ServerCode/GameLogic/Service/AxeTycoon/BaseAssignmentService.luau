--!strict

--[[
	基地分配服务（参考 dingdong 项目 BaseManagerSever 模式）。

	职责：
	- 启动时扫描 Workspace.World 下所有 Base_* 折叠进入空闲池
	- 玩家进服（数据加载完成）后分配一个空闲基地，建立双向映射，标记归属，传送
	- 玩家离开时回收基地、清除归属、解绑连接
	- 对外暴露 getBase / getOwner 供其它服务做归属校验

	设计为可扩展的多基地框架：当前物理上仅 Base_1，但池化逻辑天然支持任意数量 Base_N。
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local ReplicatedCode = ReplicatedStorage:WaitForChild("ReplicatedCode")
local ServerCode = ServerScriptService:WaitForChild("ServerCode")

local Network = require(ReplicatedCode.Framework.Core.Network)
local safePlayerAdded = require(ReplicatedCode.Framework.Utility.Player.SafePlayerAdded)
local Connections = require(ReplicatedCode.Framework.Infrastructure.Classes.Connections)
local PlayerDataServer = require(ServerCode.Framework.DataStore.PlayerData.PlayerDataServer)
local AttributeEnum = require(ReplicatedCode.GameLogic.Shared.Enums.AttributeEnum)
local PlayerDataKey = require(ReplicatedCode.GameLogic.SharedConstants.Keys.PlayerDataKey)
local RemoteEventKey = require(ReplicatedCode.GameLogic.SharedConstants.Keys.RemoteEventKey)
local Base = require(ServerCode.GameLogic.Modules.AxeTycoon.Base)
local ProcessorBaseAttributes = require(ServerCode.GameLogic.Modules.AxeTycoon.ProcessorBaseAttributes)

-- 基地归属属性名：写在 Base_* 折叠上，记录占用者的 UserId（与客户端 BaseController 共用同一枚举键）
local OWNER_ID_ATTRIBUTE = AttributeEnum.OwnerId

local BaseAssignmentService = {}

-- 空闲基地池（启动时填充，分配时取出，回收时放回）
local freeBases: { Folder } = {}
-- 双向映射：玩家 UserId -> 基地折叠 / 基地折叠 -> 玩家 UserId（后者用 OwnerId 属性承载）
local baseByUserId: { [number]: Folder } = {}
-- 玩家 UserId -> 基地运行时对象（槽位结构 + 斧头模型管理）
local baseObjectByUserId: { [number]: Base.ClassType } = {}
-- 每个玩家的连接集合（CharacterAdded 等），离开时统一断开
local connectionsByPlayer: { [Player]: Connections.ClassType } = {}
-- 回家传送冷却（秒），防止客户端高频请求
local HOME_TELEPORT_COOLDOWN = 1
local lastHomeTeleportAt: { [Player]: number } = {}

-- 扫描 Workspace.World 下所有 Base_* 折叠，按名称序号排序填充空闲池
local function collectBases()
	table.clear(freeBases)

	local world = Workspace:FindFirstChild("World")
	if not world then
		warn("[BaseAssignmentService] 未找到 Workspace.World，无法收集基地")
		return
	end

	local bases: { Folder } = {}
	for _, child in world:GetChildren() do
		if child:IsA("Folder") and string.match(child.Name, "^Base_%d+$") then
			bases[#bases + 1] = child
		end
	end

	-- 按 Base_N 的数字排序，保证分配顺序稳定（Base_1 优先）
	table.sort(bases, function(a, b)
		local na = tonumber(string.match(a.Name, "%d+")) or 0
		local nb = tonumber(string.match(b.Name, "%d+")) or 0
		return na < nb
	end)

	for _, base in bases do
		-- 清理可能残留的归属（如服务重启），仅放入未被占用的基地
		base:SetAttribute(OWNER_ID_ATTRIBUTE, nil)
		freeBases[#freeBases + 1] = base
	end
end

-- 从空闲池取出一个基地；池空返回 nil
local function takeFreeBase(): Folder?
	return table.remove(freeBases, 1)
end

-- 将玩家传送到指定基地的出生点
local function teleportToBase(player: Player, base: Folder)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local spawnLocation = base:FindFirstChild("SpawnLocation") :: BasePart?
	if root and spawnLocation then
		-- 抬高 3 study 避免卡入出生板
		root.CFrame = spawnLocation.CFrame + Vector3.new(0, 3, 0)
	end
end

-- 为玩家分配基地：取空闲基地 -> 标记归属 -> 建映射 -> 绑定角色传送
function BaseAssignmentService.assign(player: Player): Folder?
	if baseByUserId[player.UserId] then
		return baseByUserId[player.UserId]
	end

	local base = takeFreeBase()
	if not base then
		warn(string.format("[BaseAssignmentService] 没有空闲基地可分配给 %s", player.Name))
		return nil
	end

	base:SetAttribute(OWNER_ID_ATTRIBUTE, player.UserId)
	baseByUserId[player.UserId] = base

	-- 在脚本中构建基地：枚举槽位、清场，并按持久化数据重建已有斧头
	local baseObject = Base.new(base, player)
	baseObjectByUserId[player.UserId] = baseObject
	local axeTycoonData = PlayerDataServer.getValue(player, PlayerDataKey.AxeTycoon)
	if type(axeTycoonData) == "table" then
		baseObject:rebuildFromData(axeTycoonData.axes)
	end
	-- 写入处理机初始状态，供所有客户端渲染 CashWall 墙面
	ProcessorBaseAttributes.apply(base, axeTycoonData)

	local connections = connectionsByPlayer[player]
	if not connections then
		connections = Connections.new()
		connectionsByPlayer[player] = connections
	end

	-- 角色每次重生都传送回自己的基地
	connections:add(player.CharacterAdded:Connect(function()
		-- 等待 HumanoidRootPart 就绪
		task.wait()
		teleportToBase(player, base)
	end))

	-- 当前角色已存在则立即传送
	if player.Character then
		teleportToBase(player, base)
	end

	return base
end

-- 回收玩家基地：清除归属 -> 放回空闲池 -> 断开连接 -> 清映射
function BaseAssignmentService.release(player: Player)
	local connections = connectionsByPlayer[player]
	if connections then
		connections:disconnect()
		connectionsByPlayer[player] = nil
	end

	lastHomeTeleportAt[player] = nil

	local baseObject = baseObjectByUserId[player.UserId]
	if baseObject then
		-- 清场销毁斧头模型 + 槽位结构
		baseObject:destroy()
		baseObjectByUserId[player.UserId] = nil
	end

	local base = baseByUserId[player.UserId]
	if base then
		ProcessorBaseAttributes.clear(base)
		base:SetAttribute(OWNER_ID_ATTRIBUTE, nil)
		baseByUserId[player.UserId] = nil
		freeBases[#freeBases + 1] = base
	end
end

-- 查询玩家当前基地折叠
function BaseAssignmentService.getBase(player: Player): Folder?
	return baseByUserId[player.UserId]
end

-- 查询玩家基地运行时对象（槽位/放置斧子用）
function BaseAssignmentService.getBaseObject(player: Player): Base.ClassType?
	return baseObjectByUserId[player.UserId]
end

-- 查询基地归属玩家（供 Touched 归属校验）
function BaseAssignmentService.getOwner(base: Folder): Player?
	local ownerId = base:GetAttribute(OWNER_ID_ATTRIBUTE)
	if type(ownerId) ~= "number" then
		return nil
	end
	return Players:GetPlayerByUserId(ownerId)
end

-- 客户端请求回家：校验已分配基地 + 冷却后，传送回自己基地出生点
local function onHomeTeleportRequested(player: Player)
	local base = baseByUserId[player.UserId]
	if not base then
		return
	end

	local now = os.clock()
	local lastAt = lastHomeTeleportAt[player] or 0
	if now - lastAt < HOME_TELEPORT_COOLDOWN then
		return
	end
	lastHomeTeleportAt[player] = now

	teleportToBase(player, base)
end

function BaseAssignmentService.start()
	collectBases()

	Network.connectEvent(RemoteEventKey.HomeTeleport, onHomeTeleportRequested)

	local function onPlayerAdded(player: Player)
		-- 等数据加载完成，后续步骤需按持久化数据重建基地内容
		PlayerDataServer.waitForDataLoadAsync(player)
		BaseAssignmentService.assign(player)
	end

	safePlayerAdded(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		BaseAssignmentService.release(player)
	end)
end

return BaseAssignmentService
