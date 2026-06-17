--!strict

--[[
	斧子生产表现控制器（纯客户端视觉，自动扫描加载）。

	职责：
	- 为每把斧子挂载 Billboard（预制体 Prefabs.Billboard.Axe），显示木种名与等级（英文）
	- 收到 produceAnim：提前播放 axe_action 动画
	- 收到 produce：克隆木材模型，从斧子沿轨道滚向堆叠区，散落在 TouchedStacking 附近

	服务端只维护数据，木材模型与散落表现完全在客户端生成，不回传、不影响权威数据。
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local GameLogic = ReplicatedStorage.ReplicatedCode.GameLogic
local Framework = ReplicatedStorage.ReplicatedCode.Framework

local Network = require(Framework.Core.Network)
local WoodPickupPopup = require(GameLogic.Modules.WoodPickupPopup)
local WoodStackVisual = require(GameLogic.Modules.WoodStackVisual)
local AxeConfig = require(GameLogic.Shared.Configs.AxeConfig)
local AttributeEnum = require(GameLogic.Shared.Enums.AttributeEnum)
local AnimationsEnum = require(GameLogic.Shared.Enums.AnimationsEnum)
local ColorEnum = require(GameLogic.Shared.Enums.ColorEnum)
local RemoteEventKey = require(GameLogic.SharedConstants.Keys.RemoteEventKey)

-- 默认动画 ID：当某单位在 AxeConfig 未配置专属动画时回退使用
local DEFAULT_AXE_ACTION_ANIM_ID = "rbxassetid://" .. tostring(AnimationsEnum.Axe.Action)

type AxeAnimInfo = {
	actionId: string,
	idleId: string?,
}

-- 按斧子 category 解析 action / idle 动画资源 ID
local function resolveAxeAnimInfo(category: string): AxeAnimInfo
	local info = AxeConfig.Axes[category]
	local actionId = DEFAULT_AXE_ACTION_ANIM_ID
	local idleId: string? = nil
	if info then
		if type(info.action) == "number" and info.action > 0 then
			actionId = "rbxassetid://" .. tostring(info.action)
		end
		if type(info.idle) == "number" and info.idle > 0 then
			idleId = "rbxassetid://" .. tostring(info.idle)
		end
	end
	return {
		actionId = actionId,
		idleId = idleId,
	}
end

-- 动画应播在斧子子级与 category 同名的 Model 上（如 Prefabs.Axe.1.1）
local function resolveAnimModel(axe: Model): Model?
	local category = axe:GetAttribute(AttributeEnum.Category)
	if type(category) == "string" then
		local child = axe:FindFirstChild(category)
		if child and child:IsA("Model") then
			return child
		end
	end
	return axe
end
-- 砍木音效（随 axe_action 动画播放，挂在斧子部件上形成 3D 空间音效）
local CHOP_SOUND_ID = "rbxassetid://500472891"
local CHOP_SOUND_VOLUME = 0.5
-- 动画里标记「斧子劈中木头瞬间」的关键帧事件名（在动画编辑器中添加），
-- 播放到该标记时触发砍木音效、斧刃粒子与 ProduceVFX
local CHOP_MARKER_NAME = "Event"
-- 超出该距离听不到砍木声，避免远处其他基地的斧子声干扰
local CHOP_SOUND_MAX_DISTANCE = 100
-- 砍木粒子（服务端生成斧子时已克隆到 Axe.AxeRoot 上）单次发射数量，
-- 发射器配置了 EmitCount 属性时以属性为准
local CHOP_VFX_EMIT_COUNT = 15
-- 生产瞬间粒子（ReplicatedStorage/Instances/Prefabs/VFX/ProduceVFX）
local PRODUCE_VFX_NAME = "ProduceVFX"
local PRODUCE_VFX_EMIT_COUNT = 15
local PRODUCE_VFX_CLONE_LIFETIME = 2
-- 堆叠区落点 Part（WoodPile 挂在其下，位于 AxeMachine 下）
local STACKING_ANCHOR_NAME = "TouchedStacking"
local WOOD_PILE_FOLDER_NAME = "WoodPile"
-- 兜底：木材生成后若超时仍未到达落点，则强制传送到落点位置（防止卡轨）
local WOOD_FALLBACK_TIME = 16
-- 木材滚落点判定距离（stud），不再依赖 TouchedStacking 碰撞
local WOOD_ARRIVAL_DISTANCE = 4
-- 客户端检测身边木头的间隔与范围（与服务端 WoodCarryService 去抖一致）
local PICKUP_CHECK_INTERVAL = 0.25
-- 近邻拾取：水平半径 / 垂直半高（检测中心取 HRP 与脚底的中点，兼容不同身高）
local PICKUP_HORIZONTAL_RADIUS = 8
local PICKUP_VERTICAL_HALF = 10
-- 站在堆叠区内时，所有已落地物品均可拾取（无需 PrimaryPart 进入近邻盒）
local STACKING_ZONE_PICKUP_RADIUS = 14
-- 木材生成位置：斧子前方的单位数（沿斧子朝向），落到轨道上
local WOOD_SPAWN_FORWARD = 8

local AxeProductionController = {
	Name = "AxeProductionController",
	_started = false,
}

type AxeAnimTracks = {
	idle: AnimationTrack?,
	action: AnimationTrack,
}

-- 斧子模型 -> 缓存的动画轨道
local tracksByAxe: { [Model]: AxeAnimTracks } = {}
-- 斧子模型 -> 缓存的砍木音效
local soundByAxe: { [Model]: Sound } = {}
-- 基地 -> 尚未收走的木头模型 -> 木种 category
local activeWoodByBase: { [Instance]: { [Model]: string } } = {}
-- 客户端上次发起 WoodPickup 请求的时间
local lastPickupRequestAt = 0
-- 最近一次请求收集时，检测范围内待移除的木头（model + category）
type PendingPickupWood = { model: Model, category: string }
local pendingPickupWoods: { PendingPickupWood } = {}

-- Billboard 预制体
local function getBillboardPrefab(): BillboardGui?
	local instances = ReplicatedStorage:FindFirstChild("Instances")
	local prefabs = instances and instances:FindFirstChild("Prefabs")
	local billboardFolder = prefabs and prefabs:FindFirstChild("Billboard")
	local axeBillboard = billboardFolder and billboardFolder:FindFirstChild("Axe")
	if axeBillboard and axeBillboard:IsA("BillboardGui") then
		return axeBillboard
	end
	return nil
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

-- 等模型复制完整后再贴合：客户端 ChildAdded 触发时，PrimaryPart 引用与大部分后代
-- 可能尚未到达，立刻取包围盒会按半个模型算高度，导致 Billboard 挂得过低
local function fitBillboardWhenReady(billboard: BillboardGui, model: Model)
	task.spawn(function()
		-- 优先 HumanoidRootPart（人物 rig 的定位根），其引用型 PrimaryPart 复制得更晚
		local adornee: BasePart? = nil
		for _ = 1, 50 do
			local rootPart = model:FindFirstChild("HumanoidRootPart")
			if rootPart and rootPart:IsA("BasePart") then
				adornee = rootPart
				break
			end
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

-- 为斧子设置 Billboard 文本与 NameLabel 渐变（按 rarity 读 ColorEnum.Axe）
local function applyBillboardInfo(billboard: BillboardGui, category: string)
	local info = AxeConfig.Axes[category]
	if not info then
		return
	end
	local main = billboard:FindFirstChild("Main")
	if not main then
		return
	end
	local nameLabel = main:FindFirstChild("NameLabel")
	local levelLabel = main:FindFirstChild("LevelLabel")
	if nameLabel and nameLabel:IsA("TextLabel") then
		nameLabel.Text = info.name
		local gradient = nameLabel:FindFirstChildOfClass("UIGradient")
		local colorSequence = ColorEnum.Axe[info.rarity]
		if gradient and colorSequence then
			gradient.Color = colorSequence
		end
	end
	if levelLabel and levelLabel:IsA("TextLabel") then
		levelLabel.Text = "Tier " .. tostring(info.rarity)
	end
end

local setupAxeAnimation: (axe: Model) -> ()

-- 给斧子挂 Billboard（已挂则跳过）
local function attachBillboard(axe: Model)
	if axe:FindFirstChild("AxeBillboard") then
		return
	end

	local prefab = getBillboardPrefab()
	if not prefab then
		return
	end

	local billboard = prefab:Clone()
	billboard.Name = "AxeBillboard"
	billboard.Adornee = axe.PrimaryPart or axe:FindFirstChildWhichIsA("BasePart")
	billboard.Parent = axe
	fitBillboardWhenReady(billboard, axe)
	setupAxeAnimation(axe)

	local category = axe:GetAttribute(AttributeEnum.Category)
	if type(category) == "string" then
		applyBillboardInfo(billboard, category)
	else
		-- category 属性可能稍后才复制到，监听一次
		local connection: RBXScriptConnection
		connection = axe:GetAttributeChangedSignal(AttributeEnum.Category):Connect(function()
			local newCategory = axe:GetAttribute(AttributeEnum.Category)
			if type(newCategory) == "string" then
				applyBillboardInfo(billboard, newCategory)
				connection:Disconnect()
			end
		end)
	end
end

-- 产木生成基准：优先槽位原始朝向（不含放置时的视觉 180° 翻转）
local function getAxeSpawnCFrame(axe: Model): CFrame
	local original = axe:GetAttribute(AttributeEnum.OriginalCFrame)
	if typeof(original) == "CFrame" then
		return original
	end
	return axe:GetPivot()
end

-- 前置声明：砍中瞬间的音效与粒子表现（定义在下方，由动画关键帧标记触发）
local playChopEffects: (axe: Model) -> ()

local function getAnimator(model: Model): Animator?
	local controller = model:FindFirstChildOfClass("AnimationController")
		or model:FindFirstChildOfClass("Humanoid")
	if not controller then
		return nil
	end
	return controller:FindFirstChildOfClass("Animator")
end

local function loadAnimTrack(animator: Animator, animId: string, looped: boolean, priority: Enum.AnimationPriority): AnimationTrack?
	local animation = Instance.new("Animation")
	animation.AnimationId = animId
	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if not ok or not track then
		animation:Destroy()
		return nil
	end
	track.Looped = looped
	track.Priority = priority
	return track
end

local function playAxeIdle(axe: Model)
	local tracks = tracksByAxe[axe]
	if not tracks or not tracks.idle then
		return
	end
	local idleTrack = tracks.idle
	if tracks.action.IsPlaying then
		tracks.action:Stop()
	end
	if idleTrack.IsPlaying then
		return
	end
	idleTrack:Play()
end

-- 取（或创建并缓存）斧子同名子模型的 idle / action 动画轨道
local function getAxeTracks(axe: Model): AxeAnimTracks?
	local cached = tracksByAxe[axe]
	if cached then
		return cached
	end

	local category = axe:GetAttribute(AttributeEnum.Category)
	if type(category) ~= "string" then
		return nil
	end

	local animModel = resolveAnimModel(axe)
	if not animModel then
		return nil
	end

	local animator = getAnimator(animModel)
	if not animator then
		return nil
	end

	local animInfo = resolveAxeAnimInfo(category)
	local actionTrack = loadAnimTrack(animator, animInfo.actionId, false, Enum.AnimationPriority.Action)
	if not actionTrack then
		return nil
	end

	local idleTrack: AnimationTrack? = nil
	if animInfo.idleId then
		idleTrack = loadAnimTrack(animator, animInfo.idleId, true, Enum.AnimationPriority.Idle)
	end

	local tracks: AxeAnimTracks = {
		idle = idleTrack,
		action = actionTrack,
	}
	tracksByAxe[axe] = tracks

	actionTrack:GetMarkerReachedSignal(CHOP_MARKER_NAME):Connect(function()
		playChopEffects(axe)
	end)

	actionTrack.Stopped:Connect(function()
		playAxeIdle(axe)
	end)

	axe.Destroying:Connect(function()
		tracksByAxe[axe] = nil
	end)

	return tracks
end

function setupAxeAnimation(axe: Model)
	local function trySetup(): boolean
		if tracksByAxe[axe] then
			return true
		end
		local tracks = getAxeTracks(axe)
		if not tracks then
			return false
		end
		playAxeIdle(axe)
		return true
	end

	if trySetup() then
		return
	end

	local connection: RBXScriptConnection
	connection = axe:GetAttributeChangedSignal(AttributeEnum.Category):Connect(function()
		if trySetup() then
			connection:Disconnect()
		end
	end)
end

-- 堆叠区下的视觉容器
local function getWoodPileFolder(anchorPart: BasePart): Folder
	local existing = anchorPart:FindFirstChild(WOOD_PILE_FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = WOOD_PILE_FOLDER_NAME
	folder.Parent = anchorPart
	return folder
end

local localPlayer = Players.LocalPlayer

local function unregisterWood(base: Instance, wood: Model)
	local bucket = activeWoodByBase[base]
	if bucket then
		bucket[wood] = nil
	end
end

local function registerWood(base: Instance, wood: Model, woodCategory: string)
	local bucket = activeWoodByBase[base]
	if not bucket then
		bucket = {}
		activeWoodByBase[base] = bucket
	end
	bucket[wood] = woodCategory
	wood.Destroying:Connect(function()
		unregisterWood(base, wood)
	end)
end

-- 扫描 Workspace.World 下本地玩家的基地
local function findMyBase(): Instance?
	local world = Workspace:FindFirstChild("World")
	if not world then
		return nil
	end
	for _, child in world:GetChildren() do
		if child:IsA("Folder") and string.match(child.Name, "^Base_%d+$") then
			if child:GetAttribute(AttributeEnum.OwnerId) == localPlayer.UserId then
				return child
			end
		end
	end
	return nil
end

local function getStackingAnchorPart(base: Instance): BasePart?
	local axeMachine = base:FindFirstChild("InmateMachine")
	local anchorPart = axeMachine and axeMachine:FindFirstChild(STACKING_ANCHOR_NAME)
	return if anchorPart and anchorPart:IsA("BasePart") then anchorPart else nil
end

local function isPlayerInStackingZone(rootPart: BasePart, base: Instance): boolean
	local anchorPart = getStackingAnchorPart(base)
	if not anchorPart then
		return false
	end
	return (rootPart.Position - anchorPart.Position).Magnitude <= STACKING_ZONE_PICKUP_RADIUS
end

-- 拾取检测中心：HRP 与角色 bounding box 脚底的中点，减轻身高差异影响
local function getPickupDetectionCenter(character: Model, rootPart: BasePart): Vector3
	local bboxCFrame, bboxSize = character:GetBoundingBox()
	local footY = bboxCFrame.Position.Y - bboxSize.Y * 0.5
	local centerY = (rootPart.Position.Y + footY) * 0.5
	return Vector3.new(rootPart.Position.X, centerY, rootPart.Position.Z)
end

-- 木头是否已落入堆叠区（Parent 为 WoodPile 文件夹）；未落地的仍在 Workspace 飞行
local function isWoodLanded(wood: Model): boolean
	local parent = wood.Parent
	return parent ~= nil and parent.Name == WOOD_PILE_FOLDER_NAME
end

local function isPartNearPlayer(part: BasePart, character: Model, rootPart: BasePart): boolean
	local center = getPickupDetectionCenter(character, rootPart)
	local delta = part.Position - center
	return math.abs(delta.X) <= PICKUP_HORIZONTAL_RADIUS
		and math.abs(delta.Y) <= PICKUP_VERTICAL_HALF
		and math.abs(delta.Z) <= PICKUP_HORIZONTAL_RADIUS
end

-- 按服务端 taken 明细销毁模型；优先 preferModels，不足时从基地全桶按落地→飞行→任意补足
local function removeWoodVisualsByTaken(
	base: Instance,
	taken: { [string]: number },
	preferModels: { [Model]: true }?
)
	local bucket = activeWoodByBase[base]
	if not bucket then
		return
	end

	local toRemove: { Model } = {}
	local toRemoveSet: { [Model]: true } = {}

	local function markForDestroy(wood: Model)
		if not toRemoveSet[wood] then
			toRemoveSet[wood] = true
			table.insert(toRemove, wood)
		end
	end

	for category, count in taken do
		local remaining = math.floor(tonumber(count) or 0)
		if remaining <= 0 then
			continue
		end
		if preferModels then
			for wood, woodCategory in bucket do
				if remaining <= 0 then
					break
				end
				if preferModels[wood] and woodCategory == category and wood.Parent then
					markForDestroy(wood)
					remaining -= 1
				end
			end
		end
		if remaining > 0 then
			for wood, woodCategory in bucket do
				if remaining <= 0 then
					break
				end
				if not toRemoveSet[wood] and woodCategory == category and wood.Parent and isWoodLanded(wood) then
					markForDestroy(wood)
					remaining -= 1
				end
			end
		end
		if remaining > 0 then
			for wood, woodCategory in bucket do
				if remaining <= 0 then
					break
				end
				if not toRemoveSet[wood] and woodCategory == category and wood.Parent and not isWoodLanded(wood) then
					markForDestroy(wood)
					remaining -= 1
				end
			end
		end
		if remaining > 0 then
			for wood, woodCategory in bucket do
				if remaining <= 0 then
					break
				end
				if not toRemoveSet[wood] and woodCategory == category and wood.Parent then
					markForDestroy(wood)
					remaining -= 1
				end
			end
		end
	end

	for _, wood in toRemove do
		wood:Destroy()
	end
end

-- 服务端 groundTotal 对账：本地视觉数量超出权威库存时清理多余模型（幽灵物品）
local function reconcileWoodVisualCount(base: Instance, groundTotal: number)
	local bucket = activeWoodByBase[base]
	if not bucket then
		return
	end
	groundTotal = math.max(0, math.floor(groundTotal))

	local allWoods: { Model } = {}
	for wood in bucket do
		if wood.Parent then
			table.insert(allWoods, wood)
		end
	end

	local excess = #allWoods - groundTotal
	if excess <= 0 then
		return
	end

	-- 优先清理未落地 / 非网格模型，保留已落位的静态堆叠
	table.sort(allWoods, function(a, b)
		local aLanded = isWoodLanded(a)
		local bLanded = isWoodLanded(b)
		if aLanded ~= bLanded then
			return not aLanded
		end
		return false
	end)

	for i = 1, excess do
		local wood = allWoods[i]
		if wood and wood.Parent then
			wood:Destroy()
		end
	end
end

local function scanWoodInRange(
	character: Model,
	rootPart: BasePart,
	base: Instance,
	bucket: { [Model]: string }
): ({ [string]: number }, { PendingPickupWood })
	local byCategory: { [string]: number } = {}
	local inRangeEntries: { PendingPickupWood } = {}
	local inStackingZone = isPlayerInStackingZone(rootPart, base)

	for wood, category in bucket do
		if not wood.Parent then
			continue
		end
		local inRange = false
		if inStackingZone and isWoodLanded(wood) then
			inRange = true
		else
			local part = wood.PrimaryPart or wood:FindFirstChildWhichIsA("BasePart")
			inRange = part ~= nil and isPartNearPlayer(part, character, rootPart)
		end
		if inRange then
			byCategory[category] = (byCategory[category] or 0) + 1
			table.insert(inRangeEntries, { model = wood, category = category })
		end
	end

	return byCategory, inRangeEntries
end

local function tryRequestWoodPickup()
	local now = os.clock()
	if now - lastPickupRequestAt < PICKUP_CHECK_INTERVAL then
		return
	end

	local character = localPlayer.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		return
	end

	local base = findMyBase()
	if not base then
		return
	end
	local bucket = activeWoodByBase[base]
	if not bucket then
		return
	end

	local byCategory, inRangeEntries = scanWoodInRange(character, rootPart, base, bucket)
	if next(byCategory) == nil then
		return
	end

	lastPickupRequestAt = now
	pendingPickupWoods = inRangeEntries
	Network.fireServer(RemoteEventKey.WoodPickup, byCategory)
end

local function startProximityPickupLoop()
	task.spawn(function()
		while true do
			task.wait(PICKUP_CHECK_INTERVAL)
			tryRequestWoodPickup()
		end
	end)
end

-- 生成一件木材：物理下落、顺轨道滚动，散落在堆叠区落点附近
local function spawnAndStackWood(axe: Model, woodCategory: string)
	local base = findBaseAncestor(axe)
	if not base then
		return
	end
	local axeMachine = base:FindFirstChild("InmateMachine")
	local anchorPart = axeMachine and axeMachine:FindFirstChild(STACKING_ANCHOR_NAME)
	if not anchorPart or not anchorPart:IsA("BasePart") then
		return
	end

	local prefab = WoodStackVisual.resolvePrefab(woodCategory)
	if not prefab then
		return
	end

	local wood = prefab:Clone()
	WoodStackVisual.preparePhysicalModel(wood)

	local root = wood.PrimaryPart or wood:FindFirstChildWhichIsA("BasePart")
	wood:PivotTo(getAxeSpawnCFrame(axe) * CFrame.new(0, 0, -WOOD_SPAWN_FORWARD) * CFrame.Angles(0, math.rad(90), 0))
	wood.Parent = Workspace
	registerWood(base, wood, woodCategory)

	local arrived = false
	local function markArrived()
		if arrived then
			return
		end
		arrived = true
		if wood.Parent then
			wood.Parent = getWoodPileFolder(anchorPart)
		end
	end

	-- 距离判定滚落到位（不再监听 TouchedStacking 碰撞）
	task.spawn(function()
		while wood.Parent and not arrived do
			if root and (root.Position - anchorPart.Position).Magnitude <= WOOD_ARRIVAL_DISTANCE then
				markArrived()
				break
			end
			task.wait(0.2)
		end
	end)

	task.delay(WOOD_FALLBACK_TIME, function()
		if arrived then
			return
		end
		markArrived()
		if wood.Parent then
			wood:PivotTo(anchorPart.CFrame)
		end
	end)
end

-- 取（或创建并缓存）斧子的砍木音效：挂在斧子部件上，随部件位置形成 3D 空间音效
local function getChopSound(axe: Model): Sound?
	local cached = soundByAxe[axe]
	if cached then
		return cached
	end

	local part = axe.PrimaryPart or axe:FindFirstChildWhichIsA("BasePart")
	if not part then
		return nil
	end

	local sound = Instance.new("Sound")
	sound.Name = "ChopSound"
	sound.SoundId = CHOP_SOUND_ID
	sound.Volume = CHOP_SOUND_VOLUME
	sound.RollOffMaxDistance = CHOP_SOUND_MAX_DISTANCE
	sound.SoundGroup = SoundService.SFX
	sound.Parent = part
	soundByAxe[axe] = sound

	-- 斧子销毁时清理缓存（音效随部件一并销毁）
	axe.Destroying:Connect(function()
		soundByAxe[axe] = nil
	end)

	return sound
end

-- 砍木粒子挂点名称（服务端放置斧子时建在斧刃 MeshPart Axe.Axe 上，见 Slot.attachChopEmitters）
local CHOP_VFX_ATTACHMENT_NAME = "ChopVFXAttachment"

local function getProduceVfxPrefab(): BasePart?
	local instances = ReplicatedStorage:FindFirstChild("Instances")
	local prefabs = instances and instances:FindFirstChild("Prefabs")
	local vfxFolder = prefabs and prefabs:FindFirstChild("VFX")
	local prefab = vfxFolder and vfxFolder:FindFirstChild(PRODUCE_VFX_NAME)
	if prefab and prefab:IsA("BasePart") then
		return prefab
	end
	return nil
end

-- 在指定世界坐标克隆 ProduceVFX 并 Emit 一次（逻辑与 TouchButtonVFXController 一致）
local function emitProduceVfxAt(cframe: CFrame)
	local prefab = getProduceVfxPrefab()
	if not prefab then
		return
	end

	local clone = prefab:Clone()
	clone.CFrame = cframe
	clone.Parent = Workspace

	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("ParticleEmitter") then
			local emitter = descendant
			local emitCount = tonumber(emitter:GetAttribute("EmitCount")) or PRODUCE_VFX_EMIT_COUNT
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

	task.delay(PRODUCE_VFX_CLONE_LIFETIME, function()
		clone:Destroy()
	end)
end

-- 在动画模型位置播放 ProduceVFX
local function emitProduceVfx(axe: Model)
	local animModel = resolveAnimModel(axe)
	if not animModel or not animModel.Parent then
		return
	end
	emitProduceVfxAt(animModel:GetPivot())
end

-- 发射斧刃挂点上的砍木粒子（服务端放置斧子时从 DepositVFX 克隆而来）
local function emitChopParticles(axe: Model)
	local axePiece = axe:FindFirstChild("Axe")
	local axeMesh = axePiece and axePiece:FindFirstChild("Axe")
	local attachment = axeMesh and axeMesh:FindFirstChild(CHOP_VFX_ATTACHMENT_NAME)
	if not attachment then
		return
	end
	for _, child in attachment:GetChildren() do
		if child:IsA("ParticleEmitter") then
			local emitCount = tonumber(child:GetAttribute("EmitCount")) or CHOP_VFX_EMIT_COUNT
			child:Emit(emitCount)
		end
	end
end

-- 砍中瞬间表现：播放砍木音效、斧刃粒子与 ProduceVFX（由动画 "Event" 关键帧标记触发）
function playChopEffects(axe: Model)
	-- 动画播放期间斧子可能已销毁（合成/清场），音效随部件一并销毁
	if not axe.Parent then
		return
	end
	local sound = getChopSound(axe)
	if sound then
		if sound.IsPlaying then
			sound:Stop()
		end
		sound:Play()
	end
	emitChopParticles(axe)
	emitProduceVfx(axe)
end

local function playAxeAction(axe: Model)
	local tracks = getAxeTracks(axe)
	if not tracks then
		return
	end
	if tracks.idle and tracks.idle.IsPlaying then
		tracks.idle:Stop()
	end
	if tracks.action.IsPlaying then
		tracks.action:Stop()
	end
	tracks.action:Play()
end

-- 处理一次生产事件（动画已在 produceAnim 中提前播放）
local function onProduce(axe: Model, woodCategory: string)
	spawnAndStackWood(axe, woodCategory)
end

-- 监视一个 Axes.Floor_N 折叠：对现有与新增斧子挂 Billboard
local function watchAxesFloor(floorFolder: Instance)
	for _, child in floorFolder:GetChildren() do
		if child:IsA("Model") then
			attachBillboard(child)
		end
	end
	floorFolder.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			attachBillboard(child)
		end
	end)
end

-- 监视一个基地的 AxeMachine.Axes 折叠
local function watchBase(base: Instance)
	local axeMachine = base:FindFirstChild("InmateMachine")
	if not axeMachine then
		return
	end
	local axesFolder = axeMachine:FindFirstChild("Inmates")
	if not axesFolder then
		return
	end
	for _, floorFolder in axesFolder:GetChildren() do
		if floorFolder:IsA("Folder") then
			watchAxesFloor(floorFolder)
		end
	end
end

-- 监视 Workspace.World 下所有基地
local function watchWorld()
	local world = Workspace:FindFirstChild("World")
	if not world then
		world = Workspace:WaitForChild("World", 30)
	end
	if not world then
		return
	end
	for _, child in world:GetChildren() do
		if string.match(child.Name, "^Base_%d+$") then
			watchBase(child)
		end
	end
	world.ChildAdded:Connect(function(child)
		if string.match(child.Name, "^Base_%d+$") then
			watchBase(child)
		end
	end)
end

function AxeProductionController:init()
	if self._started then
		return
	end
	self._started = true

	task.spawn(watchWorld)
	startProximityPickupLoop()

	Network.connectEvent(RemoteEventKey.AxeTycoonSync, function(payload)
		if type(payload) ~= "table" then
			return
		end
		if payload.kind == "produceAnim" and typeof(payload.axe) == "Instance" and payload.axe:IsA("Model") then
			playAxeAction(payload.axe)
		elseif payload.kind == "produce" and typeof(payload.axe) == "Instance" and payload.axe:IsA("Model") then
			if type(payload.wood) == "string" then
				onProduce(payload.axe, payload.wood)
			end
		elseif payload.kind == "pickup" and typeof(payload.base) == "Instance" then
			local taken = if type(payload.taken) == "table" then payload.taken else {}
			local groundTotal = if type(payload.groundTotal) == "number" then payload.groundTotal else nil

			local preferSet: { [Model]: true } = {}
			if not payload.silent then
				for _, entry in pendingPickupWoods do
					preferSet[entry.model] = true
				end
			end

			if next(taken) ~= nil then
				removeWoodVisualsByTaken(payload.base, taken, if next(preferSet) then preferSet else nil)
			end
			if groundTotal ~= nil then
				reconcileWoodVisualCount(payload.base, groundTotal)
			end
			table.clear(pendingPickupWoods)

			-- 本地玩家自己拾取时，在 HUD WoodAmount 上方弹出拾取飘字（明细由服务端随广播下发）
			-- silent 为 true（如自动收集通行证）时只清理模型、不弹飘字
			if
				not payload.silent
				and next(taken) ~= nil
				and payload.base:GetAttribute(AttributeEnum.OwnerId) == localPlayer.UserId
			then
				SoundService.SFX.TryOnAdd:Play()
				WoodPickupPopup.show(taken)
			end
		end
	end, Network.t.table)
end

return AxeProductionController
