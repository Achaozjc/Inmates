--!strict

--[[
	宝箱生产表现控制器（纯客户端视觉，自动扫描加载）。

	职责：收到服务端 AxeTycoonSync 的 chestSpawn / chestExpire 事件时——
	- chestSpawn：克隆宝箱预制体（Instances.Prefabs.Chest.<level>），从产木的斧子前方靠物理滑到轨道上，
	  触碰所属基地 AxeMachine.TouchedStacking 后，直接码放到 Base_*.Chest.ChestPlace 的第 slot 个 Attachment 上，并播放 DepositVFX。
	- chestExpire：销毁对应 id 的宝箱模型（存在时间到 / 玩家离开）。

	与木头一致：服务端只维护数据（见 ChestState），宝箱模型与码放完全在客户端生成。
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() :: Player

local GameLogic = ReplicatedStorage.ReplicatedCode.GameLogic
local Framework = ReplicatedStorage.ReplicatedCode.Framework

local Network = require(Framework.Core.Network)
local WoodStackVisual = require(GameLogic.Modules.WoodStackVisual)
local ChestConfig = require(GameLogic.Shared.Configs.ChestConfig)
local AttributeEnum = require(GameLogic.Shared.Enums.AttributeEnum)
local ColorEnum = require(GameLogic.Shared.Enums.ColorEnum)
local TagCategory = require(GameLogic.SharedConstants.Categories.TagCategory)
local RemoteEventKey = require(GameLogic.SharedConstants.Keys.RemoteEventKey)

-- 触发码放的触发区（与木头共用，位于 AxeMachine 下）
local STACKING_TRIGGER_NAME = "TouchedStacking"
-- 宝箱码放容器路径：Base_*.Chest.ChestPlace（其子级 Attachment 命名为 "1".."10"）
local CHEST_FOLDER_NAME = "Chests"
local CHEST_PLACE_NAME = "ChestPlace"
-- 兜底：生成后若超时仍未触碰触发区，则强制码放（防止卡轨）
local CHEST_FALLBACK_TIME = 8
-- 生成位置：斧子前方的单位数（沿斧子朝向），落到轨道上
local CHEST_SPAWN_FORWARD = 8
-- 码放高度偏移（世界 Y）：在 ChestPlace Attachment 基础上下移
local CHEST_PLACE_HEIGHT_OFFSET = -3.2
-- 捡起请求超时：超过该时长宝箱模型仍在（服务端拒绝了请求），清除去抖标记允许再次尝试
local PICKUP_RETRY_TIME = 2
-- 码放入位粒子特效（与 TouchButtonVFXController Storage 按钮一致）
local DEPOSIT_VFX_NAME = "DepositVFX"
local DEFAULT_EMIT_COUNT = 15
local VFX_CLONE_LIFETIME = 2

local ChestProductionController = {
	Name = "ChestProductionController",
	_started = false,
}

-- 宝箱 id -> 客户端模型（便于到期/离场销毁）
local modelById: { [number]: Model } = {}
-- 已发起捡起请求的宝箱 id（去抖，避免 Touched 重复触发）
local pickupRequested: { [number]: boolean } = {}

-- 解析宝箱预制体（Instances.Prefabs.Chest.<category>）
local function resolveChestPrefab(category: string): Model?
	local instances = ReplicatedStorage:FindFirstChild("Instances")
	local prefabs = instances and instances:FindFirstChild("Prefabs")
	local chestFolder = prefabs and prefabs:FindFirstChild("Chest")
	if not chestFolder then
		return nil
	end
	local prefab = chestFolder:FindFirstChild(category) or chestFolder:FindFirstChild("1")
	if prefab and prefab:IsA("Model") then
		return prefab
	end
	return nil
end

-- 解析宝箱 Billboard 预制体（Instances.Prefabs.Billboard.Chest）
local function getChestBillboardPrefab(): BillboardGui?
	local instances = ReplicatedStorage:FindFirstChild("Instances")
	local prefabs = instances and instances:FindFirstChild("Prefabs")
	local billboardFolder = prefabs and prefabs:FindFirstChild("Billboard")
	local chestBillboard = billboardFolder and billboardFolder:FindFirstChild("Chest")
	if chestBillboard and chestBillboard:IsA("BillboardGui") then
		return chestBillboard
	end
	return nil
end

-- 倒计时格式 m:ss
local function formatCountdown(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

-- 按模型包围盒高度调整 Billboard 垂直偏移，使其贴合模型顶部
-- 预制体里的 StudsOffsetWorldSpace 是固定值，模型矮时会悬空、高时会穿模
local function fitBillboardToModel(billboard: BillboardGui, model: Model, adornee: BasePart)
	local boxCFrame, boxSize = model:GetBoundingBox()
	local topY = boxCFrame.Position.Y + boxSize.Y / 2
	-- Billboard 以中心点定位，Size 的 Scale 分量即世界格数，抬高半个面板再留一点间隙
	local halfPanelHeight = billboard.Size.Y.Scale / 2
	local gap = 0.5
	local offsetY = (topY - adornee.Position.Y) + halfPanelHeight + gap
	billboard.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
end

-- 等模型复制完整后再贴合：客户端拿到模型时，PrimaryPart 引用与部分后代可能尚未到达，
-- 立刻取包围盒会按不完整的模型算高度，导致 Billboard 挂得过低
local function fitBillboardWhenReady(billboard: BillboardGui, model: Model)
	task.spawn(function()
		local adornee: BasePart? = nil
		for _ = 1, 50 do
			adornee = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
			if adornee then
				break
			end
			task.wait(0.1)
		end
		if not adornee or not billboard.Parent then
			return
		end
		billboard.Adornee = adornee

		-- 等包围盒高度连续两次基本不变（后代到齐）再计算，最多等 2 秒兜底
		local lastHeight = -1
		for _ = 1, 20 do
			local _, boxSize = model:GetBoundingBox()
			if math.abs(boxSize.Y - lastHeight) < 0.05 then
				break
			end
			lastHeight = boxSize.Y
			task.wait(0.1)
		end
		if billboard.Parent then
			fitBillboardToModel(billboard, model, adornee)
		end
	end)
end

-- 给宝箱挂 Billboard：显示名称（按稀有度渐变）与剩余存在时间倒计时
local function attachChestBillboard(chest: Model, category: string)
	local prefab = getChestBillboardPrefab()
	if not prefab then
		return
	end
	local info = ChestConfig.Chests[category]

	local billboard = prefab:Clone()
	billboard.Adornee = chest.PrimaryPart or chest:FindFirstChildWhichIsA("BasePart")

	local main = billboard:FindFirstChild("Main")
	local nameLabel = main and main:FindFirstChild("NameLabel")
	local countDown = main and main:FindFirstChild("CountDown")

	if nameLabel and nameLabel:IsA("TextLabel") then
		nameLabel.Text = ChestConfig.getChestName(category)
		local gradient = nameLabel:FindFirstChildOfClass("UIGradient")
		local colorSequence = info and ColorEnum.Axe[info.rarity]
		if gradient and colorSequence then
			gradient.Color = colorSequence
		end
	end

	billboard.Parent = chest
	-- 必须在设置 Parent 之后调用：协程内以 billboard.Parent 判断是否已被销毁
	fitBillboardWhenReady(billboard, chest)

	-- 倒计时：从 existTime 递减到 0；宝箱被捡起/到期销毁后自动停止
	if countDown and countDown:IsA("TextLabel") then
		local remaining = (info and info.existTime) or 100
		task.spawn(function()
			while chest.Parent and remaining >= 0 do
				countDown.Text = formatCountdown(remaining)
				task.wait(1)
				remaining -= 1
			end
		end)
	end
end

-- 向上找到斧子所属的 Base_* 折叠
local function findBaseAncestor(instance: Instance): Instance?
	local current: Instance? = instance
	while current do
		if string.match(current.Name, "^Base_%d+$") then
			return current
		end
		current = current.Parent
	end
	return nil
end

-- 取某基地 ChestPlace 下第 slot 个 Attachment（不存在返回 nil）
local function getSlotAttachment(base: Instance, slot: number): Attachment?
	local chestFolder = base:FindFirstChild(CHEST_FOLDER_NAME)
	local chestPlace = chestFolder and chestFolder:FindFirstChild(CHEST_PLACE_NAME)
	if not chestPlace then
		return nil
	end
	local attachment = chestPlace:FindFirstChild(tostring(slot))
	if attachment and attachment:IsA("Attachment") then
		return attachment
	end
	return nil
end

-- 本地角色/背包是否已持有宝箱 Tool（持有时服务端必拒绝捡起，客户端直接不发请求）
local function isHoldingChestTool(): boolean
	local function scan(container: Instance?): boolean
		if not container then
			return false
		end
		for _, child in container:GetChildren() do
			if child:IsA("Tool") and child:HasTag(TagCategory.ChestTool) then
				return true
			end
		end
		return false
	end
	return scan(localPlayer.Character) or scan(localPlayer:FindFirstChild("Backpack"))
end

-- 码放到位后开启「触碰捡起」：本地角色触碰宝箱任一部件 → 请求服务端捡起（一次性）
local function enablePickup(chest: Model, id: number)
	local function onTouched(hit: BasePart)
		if pickupRequested[id] then
			return
		end
		-- 已手持宝箱时不发请求也不置去抖标记，丢弃手中宝箱后仍可正常捡起
		if isHoldingChestTool() then
			return
		end
		local character = localPlayer.Character
		if character and hit:IsDescendantOf(character) then
			pickupRequested[id] = true
			Network.fireServer(RemoteEventKey.ChestPickup, id)
			-- 兜底：捡起成功服务端会广播 chestExpire 销毁模型；若超时模型仍在，
			-- 说明请求被拒绝（如竞态下已持有宝箱），清除去抖标记允许再次触碰捡起
			task.delay(PICKUP_RETRY_TIME, function()
				if modelById[id] then
					pickupRequested[id] = nil
				end
			end)
		end
	end

	for _, part in chest:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanTouch = true
			part.Touched:Connect(onTouched)
		end
	end
end

local function getDepositVfxPrefab(): BasePart?
	local instances = ReplicatedStorage:FindFirstChild("Instances")
	local prefabs = instances and instances:FindFirstChild("Prefabs")
	local vfxFolder = prefabs and prefabs:FindFirstChild("VFX")
	local prefab = vfxFolder and vfxFolder:FindFirstChild(DEPOSIT_VFX_NAME)
	if prefab and prefab:IsA("BasePart") then
		return prefab
	end
	return nil
end

-- 在指定世界坐标播放粒子 Emit 特效（逻辑与 TouchButtonVFXController 一致）
local function playVfxAt(prefab: BasePart, cframe: CFrame)
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

local function playDepositVfx(cframe: CFrame)
	local prefab = getDepositVfxPrefab()
	if prefab then
		playVfxAt(prefab, cframe)
	end
end

-- 将宝箱直接设置到码放位（Attachment 世界 CFrame），锚定定型并开启捡起
local function placeChestToSlot(chest: Model, attachment: Attachment, id: number)
	WoodStackVisual.prepareStaticModel(chest)

	local goalCF = attachment.WorldCFrame + Vector3.new(0, CHEST_PLACE_HEIGHT_OFFSET, 0)
	if chest.Parent then
		chest:PivotTo(goalCF)
		playDepositVfx(goalCF)
		enablePickup(chest, id)
	end
end

-- 生成基准：优先槽位原始朝向（不含放置时的视觉 180° 翻转）
local function getAxeSpawnCFrame(axe: Model): CFrame
	local original = axe:GetAttribute(AttributeEnum.OriginalCFrame)
	if typeof(original) == "CFrame" then
		return original
	end
	return axe:GetPivot()
end

-- 生成一个宝箱：物理下滑、顺轨道滑动，触碰 TouchedStacking 后直接入位
local function spawnChest(axe: Model, category: string, id: number, slot: number)
	local base = findBaseAncestor(axe)
	if not base then
		return
	end
	local axeMachine = base:FindFirstChild("InmateMachine")
	local triggerPart = axeMachine and axeMachine:FindFirstChild(STACKING_TRIGGER_NAME)
	local attachment = getSlotAttachment(base, slot)
	if not attachment then
		return
	end

	local prefab = resolveChestPrefab(category)
	if not prefab then
		return
	end

	local chest = prefab:Clone()
	-- 物理滑动态：靠 RootPart 碰撞顺轨道下滑
	WoodStackVisual.preparePhysicalModel(chest)

	local root = chest.PrimaryPart or chest:FindFirstChildWhichIsA("BasePart")
	-- 在斧子前方 CHEST_SPAWN_FORWARD 个单位处生成，落到轨道上
	chest:PivotTo(getAxeSpawnCFrame(axe) * CFrame.new(0, 0, -CHEST_SPAWN_FORWARD))
	chest:SetAttribute("_chestId", id)
	chest.Parent = Workspace

	-- 挂名称 + 倒计时 Billboard
	attachChestBillboard(chest, category)

	modelById[id] = chest
	-- 模型若被提前销毁，清理索引
	chest.Destroying:Connect(function()
		if modelById[id] == chest then
			modelById[id] = nil
		end
	end)

	-- 仅触发一次：触碰触发区或超时兜底，均直接入位
	local stacked = false
	local touchConnection: RBXScriptConnection? = nil
	local function beginStack()
		if stacked then
			return
		end
		stacked = true
		if touchConnection then
			touchConnection:Disconnect()
			touchConnection = nil
		end
		if chest.Parent then
			placeChestToSlot(chest, attachment, id)
		end
	end

	-- 监听宝箱滑入 TouchedStacking 触发区
	if root and triggerPart and triggerPart:IsA("BasePart") then
		touchConnection = root.Touched:Connect(function(hit)
			if hit == triggerPart then
				beginStack()
			end
		end)
	end

	-- 兜底：超时仍未触碰（卡轨/掉落异常）则强制入位
	task.delay(CHEST_FALLBACK_TIME, beginStack)
end

-- 销毁指定 id 的宝箱模型
local function expireChest(id: number)
	pickupRequested[id] = nil
	local chest = modelById[id]
	if chest then
		modelById[id] = nil
		chest:Destroy()
	end
end

function ChestProductionController:init()
	if self._started then
		return
	end
	self._started = true

	Network.connectEvent(RemoteEventKey.AxeTycoonSync, function(payload)
		if type(payload) ~= "table" then
			return
		end
		if payload.kind == "chestSpawn" then
			if
				typeof(payload.axe) == "Instance"
				and payload.axe:IsA("Model")
				and type(payload.chest) == "string"
				and type(payload.id) == "number"
				and type(payload.slot) == "number"
			then
				spawnChest(payload.axe, payload.chest, payload.id, payload.slot)
			end
		elseif payload.kind == "chestExpire" then
			if type(payload.id) == "number" then
				expireChest(payload.id)
			end
		end
	end, Network.t.table)
end

return ChestProductionController
