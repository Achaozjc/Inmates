--!strict

--[[
	离线木堆控制器（纯客户端）。

	本地玩家有未领取离线木料（PlayerData.AxeTycoon.pendingOfflineWood > 0）时，
	在自己基地 SpawnLocation 附近克隆木堆预制体（ReplicatedStorage/Instances/Prefabs/OfflineWoodPile），
	RootPart 下的 Billboard 显示可领取数量；触碰后 fire OfflineWoodClaim 请求服务端领取。

	领取后服务端清零 pendingOfflineWood，经 PlayerData 同步回来 → 此处移除木堆并播放
	Merge 按钮同款 SFX/Whoosh + MergeVFX。
	发放与结算逻辑见服务端 OfflineWoodService。
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Framework = ReplicatedStorage.ReplicatedCode.Framework
local GameLogic = ReplicatedStorage.ReplicatedCode.GameLogic

local PlayerDataClient = require(Framework.DataStore.PlayerDataClient)
local ShowUnitNum = require(Framework.UI.ShowUnitNum)
local Network = require(Framework.Core.Network)
local AttributeEnum = require(GameLogic.Shared.Enums.AttributeEnum)
local PlayerDataKey = require(GameLogic.SharedConstants.Keys.PlayerDataKey)
local RemoteEventKey = require(GameLogic.SharedConstants.Keys.RemoteEventKey)

local localPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() :: Player

local PREFAB_NAME = "OfflineWoodPile"
local ROOT_PART_NAME = "RootPart"
local MERGE_VFX_NAME = "MergeVFX"
local DEFAULT_EMIT_COUNT = 15
local VFX_CLONE_LIFETIME = 2
-- 木堆相对 SpawnLocation 的摆放偏移（贴地、稍向前），可按美术微调
local SPAWN_OFFSET = CFrame.new(8, 0, -12)

local OfflineWoodPileController = {
	Name = "OfflineWoodPileController",
	_started = false,
	_prefab = nil :: Model?,
	_prefabMissingWarned = false,
	_pile = nil :: Model?,
	_label = nil :: TextLabel?,
	_claiming = false, -- 已发出领取请求、等待服务端清零期间不再重复发
}

-- 读取本地玩家当前未领取离线木料
local function getPending(): number
	local axeTycoon = PlayerDataClient.get(PlayerDataKey.AxeTycoon)
	if type(axeTycoon) ~= "table" then
		return 0
	end
	return math.max(0, math.floor(tonumber(axeTycoon.pendingOfflineWood) or 0))
end

local function findBaseByOwner(userId: number): Folder?
	local world = Workspace:FindFirstChild("World")
	if not world then
		return nil
	end
	for _, child in world:GetChildren() do
		if child:IsA("Folder") and string.match(child.Name, "^Base_%d+$") then
			if child:GetAttribute(AttributeEnum.OwnerId) == userId then
				return child :: Folder
			end
		end
	end
	return nil
end

-- 等待本地玩家基地及其 SpawnLocation 就绪
local function waitForMySpawn(): BasePart
	while true do
		local base = findBaseByOwner(localPlayer.UserId)
		local spawnLocation = base and base:FindFirstChild("SpawnLocation")
		if spawnLocation and spawnLocation:IsA("BasePart") then
			return spawnLocation :: BasePart
		end
		task.wait(0.1)
	end
end

-- 带超时的 WaitForChild 链式查找：刚进服时实例可能尚未复制完成
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

-- 解析木堆预制体（ReplicatedStorage.Instances.Prefabs.OfflineWoodPile）
local function resolvePrefab(): Model?
	local prefab = waitForDescendant(ReplicatedStorage, { "Instances", "Prefabs", PREFAB_NAME }, 10)
	return if prefab and prefab:IsA("Model") then prefab else nil
end

-- 在 RootPart/Billboard 下找名为 Amount 的 TextLabel 用于显示数量
local function findBillboardLabel(pile: Model): TextLabel?
	local root = pile:FindFirstChild(ROOT_PART_NAME)
	local searchRoot: Instance = root or pile
	local amount = searchRoot:FindFirstChild("Amount", true)
	return if amount and amount:IsA("TextLabel") then amount else nil
end

local function getVfxFolder(): Instance?
	local instances = ReplicatedStorage:FindFirstChild("Instances")
	local prefabs = instances and instances:FindFirstChild("Prefabs")
	return prefabs and prefabs:FindFirstChild("VFX")
end

-- 在指定位置播放 Merge 按钮同款 VFX（逻辑与 TouchButtonVFXController 一致）
local function playMergeVfxAt(cframe: CFrame)
	local vfxFolder = getVfxFolder()
	local prefab = vfxFolder and vfxFolder:FindFirstChild(MERGE_VFX_NAME)
	if not prefab or not prefab:IsA("BasePart") then
		return
	end

	local clone = prefab:Clone()
	clone.CFrame = cframe
	clone.Parent = Workspace

	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("ParticleEmitter") then
			local emitter = descendant
			local emitCount = tonumber(emitter:GetAttribute("EmitCount")) or DEFAULT_EMIT_COUNT
			local emitDelay = tonumber(emitter:GetAttribute("EmitDelay")) or 0
			if emitDelay > 0 then
				task.delay(emitDelay, function()
					if emitter.Parent then
						emitter:Emit(emitCount)
					end
				end)
			else
				emitter:Emit(emitCount)
			end
		end
	end

	task.delay(VFX_CLONE_LIFETIME, function()
		clone:Destroy()
	end)
end

function OfflineWoodPileController:_updateLabel(amount: number)
	local label = self._label
	if label then
		label.Text = ShowUnitNum(amount) .. " Items"
	end
end

function OfflineWoodPileController:_onTouched(otherPart: BasePart)
	if self._claiming then
		return
	end
	local character = otherPart.Parent
	if not character then
		return
	end
	if Players:GetPlayerFromCharacter(character) ~= localPlayer then
		return
	end
	if getPending() <= 0 then
		return
	end

	self._claiming = true
	Network.fireServer(RemoteEventKey.OfflineWoodClaim)
end

-- 生成木堆并摆到基地 SpawnLocation 附近
function OfflineWoodPileController:_spawnPile(amount: number)
	if self._pile then
		self:_updateLabel(amount)
		return
	end

	if not self._prefab then
		if not self._prefabMissingWarned then
			self._prefabMissingWarned = true
			warn("[OfflineWoodPileController] 未找到预制体 ReplicatedStorage/Instances/Prefabs/" .. PREFAB_NAME)
		end
		return
	end

	local base = findBaseByOwner(localPlayer.UserId)
	local spawnLocation = base and base:FindFirstChild("SpawnLocation")
	if not (spawnLocation and spawnLocation:IsA("BasePart")) then
		return
	end

	local pile = self._prefab:Clone()
	local root = pile:FindFirstChild(ROOT_PART_NAME)
	if root and root:IsA("BasePart") then
		pile.PrimaryPart = root
	end
	pile:PivotTo((spawnLocation :: BasePart).CFrame * SPAWN_OFFSET)
	pile.Parent = Workspace

	self._pile = pile
	self._label = findBillboardLabel(pile)
	self:_updateLabel(amount)

	-- 触碰任意部件即可领取
	for _, part in pile:GetDescendants() do
		if part:IsA("BasePart") then
			part.Touched:Connect(function(otherPart)
				self:_onTouched(otherPart)
			end)
		end
	end
end

function OfflineWoodPileController:_playClaimFeedback()
	SoundService.SFX.Whoosh:Play()
	local pile = self._pile
	if pile then
		playMergeVfxAt(pile:GetPivot())
	end
end

function OfflineWoodPileController:_removePile()
	if self._pile then
		self._pile:Destroy()
		self._pile = nil
		self._label = nil
	end
	self._claiming = false
end

-- 据当前未领取量决定生成 / 刷新 / 移除木堆
function OfflineWoodPileController:_refresh()
	local pending = getPending()
	if pending > 0 then
		self._claiming = false
		self:_spawnPile(pending)
	else
		if self._claiming then
			self:_playClaimFeedback()
		end
		self:_removePile()
	end
end

function OfflineWoodPileController:init()
	if self._started then
		return
	end
	self._started = true

	task.spawn(function()
		if not PlayerDataClient.hasLoaded() then
			PlayerDataClient.loaded:Wait()
		end

		-- 先确保基地 SpawnLocation 就绪，避免进服瞬间无法落位
		waitForMySpawn()

		-- 预制体路径固定，进服时等待复制完成后再缓存
		self._prefab = resolvePrefab()

		-- 先连信号再首刷，避免错过进服结算事件（_refresh 幂等，重复无害）
		-- pendingOfflineWood 随 AxeTycoon 同步变化（结算发放 / 领取清零）→ 刷新木堆
		PlayerDataClient.getUpdateSignal(PlayerDataKey.AxeTycoon):Connect(function()
			self:_refresh()
		end)

		self:_refresh()
	end)
end

return OfflineWoodPileController
