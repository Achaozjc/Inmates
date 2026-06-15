--!strict

--[[
	斧子生产表现控制器（纯客户端视觉，自动扫描加载）。

	职责：
	- 为每把斧子挂载 Billboard（预制体 Prefabs.Billboard.Axe），显示木种名与等级（英文）
	- 收到 produceAnim：提前播放 axe_action 动画
	- 收到 produce：克隆木材模型，从斧子滚向所属基地的 TouchedStacking 触发区（兼堆叠锚点）做堆叠效果

	服务端只维护数据，木材模型与堆叠完全在客户端生成，不回传、不影响权威数据。
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local GameLogic = ReplicatedStorage.ReplicatedCode.GameLogic
local Framework = ReplicatedStorage.ReplicatedCode.Framework

local Network = require(Framework.Core.Network)
local CharacterBackpackController = require(GameLogic.Controllers.CharacterBackpackController)
local WoodPickupPopup = require(GameLogic.Modules.WoodPickupPopup)
local WoodStackVisual = require(GameLogic.Modules.WoodStackVisual)
local AxeConfig = require(GameLogic.Shared.Configs.AxeConfig)
local AttributeEnum = require(GameLogic.Shared.Enums.AttributeEnum)
local AnimationsEnum = require(GameLogic.Shared.Enums.AnimationsEnum)
local ColorEnum = require(GameLogic.Shared.Enums.ColorEnum)
local RemoteEventKey = require(GameLogic.SharedConstants.Keys.RemoteEventKey)

local AXE_ACTION_ANIM_ID = "rbxassetid://" .. tostring(AnimationsEnum.Axe.Action)
-- 砍木音效（随 axe_action 动画播放，挂在斧子部件上形成 3D 空间音效）
local CHOP_SOUND_ID = "rbxassetid://9113801512"
local CHOP_SOUND_VOLUME = 3
-- 动画里标记「斧子劈中木头瞬间」的关键帧事件名（在动画编辑器中添加），
-- 播放到该标记时触发砍木音效与粒子
local CHOP_MARKER_NAME = "Event"
-- 超出该距离听不到砍木声，避免远处其他基地的斧子声干扰
local CHOP_SOUND_MAX_DISTANCE = 100
-- 砍木粒子（服务端生成斧子时已克隆到 Axe.AxeRoot 上）单次发射数量，
-- 发射器配置了 EmitCount 属性时以属性为准
local CHOP_VFX_EMIT_COUNT = 15
-- 木材滚动到位后的触发区，同时兼作堆叠锚点（码放位与 WoodPile 均以它为基准，位于 AxeMachine 下）
local STACKING_TRIGGER_NAME = "TouchedStacking"
local WOOD_PILE_FOLDER_NAME = "WoodPile"
-- 触发堆叠后，木材 tween 到码放位的时长
local WOOD_TWEEN_TIME = 0.4
-- 兜底：木材生成后若超时仍未触碰触发区，则强制堆叠（防止卡轨）
local WOOD_FALLBACK_TIME = 8
-- 木材生成位置：斧子前方的单位数（沿斧子朝向），落到轨道上
local WOOD_SPAWN_FORWARD = 8

local AxeProductionController = {
	Name = "AxeProductionController",
	_started = false,
}

-- 斧子模型 -> 缓存的动画轨道
local trackByAxe: { [Model]: AnimationTrack } = {}
-- 斧子模型 -> 缓存的砍木音效
local soundByAxe: { [Model]: Sound } = {}
-- 基地折叠 -> 已堆叠木材数（用于计算下一码放位）
local stackCountByBase: { [Instance]: number } = {}
-- 基地折叠 -> 飞行中（tween 入堆途中）的木材及其重定向函数。
-- 拾取清堆时计数归零，飞行中的木头须重新取低位槽，否则会按旧槽位浮空码放
local inFlightByBase: { [Instance]: { [Model]: () -> () } } = {}

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

-- 取（或创建并缓存）斧子的 axe_action 动画轨道
local function getAxeTrack(axe: Model): AnimationTrack?
	local cached = trackByAxe[axe]
	if cached then
		return cached
	end

	-- 人物 rig 的 Animator 挂在 Humanoid 下，普通模型则用 AnimationController
	local controller = axe:FindFirstChildOfClass("AnimationController")
		or axe:FindFirstChildOfClass("Humanoid")
	if not controller then
		return nil
	end
	local animator = controller:FindFirstChildOfClass("Animator")
	if not animator then
		return nil
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = AXE_ACTION_ANIM_ID
	local track = animator:LoadAnimation(animation)
	trackByAxe[axe] = track

	-- 播放到 "Event" 关键帧标记（斧子劈中木头瞬间）时播放音效与粒子
	track:GetMarkerReachedSignal(CHOP_MARKER_NAME):Connect(function()
		playChopEffects(axe)
	end)

	-- 斧子销毁时清理缓存
	axe.Destroying:Connect(function()
		trackByAxe[axe] = nil
	end)

	return track
end

-- 堆叠区下的视觉容器（背负 pickup 时整夹清空）
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

local function clearWoodPile(base: Instance)
	local axeMachine = base:FindFirstChild("InmateMachine")
	local anchorPart = axeMachine and axeMachine:FindFirstChild(STACKING_TRIGGER_NAME)
	if not anchorPart or not anchorPart:IsA("BasePart") then
		return
	end
	local pile = anchorPart:FindFirstChild(WOOD_PILE_FOLDER_NAME)
	if pile then
		-- 本地玩家拾取自家堆叠区：地面堆模型整体过继给背负控制器复用
		-- （免销毁 + 免克隆，消除拾取瞬间的单帧尖峰）；其他玩家的堆照常清空
		if base:GetAttribute(AttributeEnum.OwnerId) == localPlayer.UserId then
			local models: { Model } = {}
			for _, child in pile:GetChildren() do
				if child:IsA("Model") then
					models[#models + 1] = child
				end
			end
			if #models > 0 then
				CharacterBackpackController:adoptModels(models)
			end
		end
		pile:ClearAllChildren()
	end
	stackCountByBase[base] = 0

	-- 计数已归零：飞行中的木头重定向到新的低位槽，否则会按拾取前的旧槽位浮空码放
	local flights = inFlightByBase[base]
	if flights then
		for _, retarget in flights do
			retarget()
		end
	end
end

-- 堆叠整体码放偏移（锚点局部空间）：Y 向下 6，向后（+Z）方向（-1）
local STACK_AREA_OFFSET = Vector3.new(0, -6, -1)

-- 计算下一个木材的码放世界 CFrame（以堆叠锚点为基准）
local function getNextStackCFrame(base: Instance, anchorPart: BasePart): CFrame
	local n = stackCountByBase[base] or 0
	stackCountByBase[base] = n + 1
	local offset = WoodStackVisual.getGridOffset(n, WoodStackVisual.GROUND_BASE_HEIGHT_OFFSET) + STACK_AREA_OFFSET
	return anchorPart.CFrame * CFrame.new(offset)
end

-- 将木材从当前位置 tween 到码放位，到位后归入 WoodPile（堆叠定型）。
-- 飞行期间登记到 inFlightByBase，拾取清堆时可重定向到归零后的新低位槽
local function tweenWoodToStack(wood: Model, base: Instance, anchorPart: BasePart)
	-- 先固定，停止物理，避免物理与 tween 互相打架
	WoodStackVisual.prepareStaticModel(wood)

	local cfValue = Instance.new("CFrameValue")
	cfValue.Value = wood:GetPivot()
	local moveConnection = cfValue:GetPropertyChangedSignal("Value"):Connect(function()
		if wood.Parent then
			wood:PivotTo(cfValue.Value)
		end
	end)

	local baseFlights = inFlightByBase[base]
	if not baseFlights then
		baseFlights = {}
		inFlightByBase[base] = baseFlights
	end

	local currentTween: Tween? = nil

	local function finish(goalCF: CFrame)
		baseFlights[wood] = nil
		moveConnection:Disconnect()
		cfValue:Destroy()
		if wood.Parent then
			wood:PivotTo(goalCF)
			wood.Parent = getWoodPileFolder(anchorPart)
		end
	end

	-- 从当前位置 tween 到指定槽位；重定向时取消旧 tween 从中途位置续飞
	local function playTo(goalCF: CFrame)
		if currentTween then
			currentTween:Cancel()
		end
		local tween = TweenService:Create(
			cfValue,
			TweenInfo.new(WOOD_TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Value = goalCF }
		)
		currentTween = tween
		tween.Completed:Connect(function(state)
			-- Cancel 也会触发 Completed，仅在真正播完时定型
			if state == Enum.PlaybackState.Completed then
				finish(goalCF)
			end
		end)
		tween:Play()
	end

	-- 木材意外销毁时清理登记，防止重定向访问已销毁实例
	wood.Destroying:Once(function()
		baseFlights[wood] = nil
		moveConnection:Disconnect()
		cfValue:Destroy()
	end)

	baseFlights[wood] = function()
		playTo(getNextStackCFrame(base, anchorPart))
	end
	playTo(getNextStackCFrame(base, anchorPart))
end

-- 生成一件木材：物理下落、顺轨道滚动，触碰 TouchedStacking 后再 tween 入堆
local function spawnAndStackWood(axe: Model, woodCategory: string)
	local base = findBaseAncestor(axe)
	if not base then
		return
	end
	local axeMachine = base:FindFirstChild("InmateMachine")
	-- TouchedStacking 既是滚动触发区，也作为堆叠锚点
	local triggerPart = axeMachine and axeMachine:FindFirstChild(STACKING_TRIGGER_NAME)
	if not triggerPart or not triggerPart:IsA("BasePart") then
		return
	end

	local prefab = WoodStackVisual.resolvePrefab(woodCategory)
	if not prefab then
		return
	end

	local wood = prefab:Clone()
	-- 物理滚动态：不锚定，靠 RootPart 球体顺轨道滚动
	WoodStackVisual.preparePhysicalModel(wood)

	local root = wood.PrimaryPart or wood:FindFirstChildWhichIsA("BasePart")
	-- 在斧子前方 WOOD_SPAWN_FORWARD 个单位处生成，并绕竖直轴旋转 90°，让木头落到轨道上
	wood:PivotTo(getAxeSpawnCFrame(axe) * CFrame.new(0, 0, -WOOD_SPAWN_FORWARD) * CFrame.Angles(0, math.rad(90), 0))
	wood.Parent = Workspace

	-- 仅触发一次：触碰触发区或超时兜底，均切换为入堆 tween
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
		if wood.Parent then
			tweenWoodToStack(wood, base, triggerPart)
		end
	end

	-- 监听木材滚入 TouchedStacking 触发区
	if root then
		touchConnection = root.Touched:Connect(function(hit)
			if hit == triggerPart then
				beginStack()
			end
		end)
	end

	-- 兜底：超时仍未触碰（卡轨/掉落异常）则强制入堆
	task.delay(WOOD_FALLBACK_TIME, beginStack)
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
	-- 归入 SFX 分组，统一受音效音量控制
	local sfxGroup = SoundService:FindFirstChild("SFX")
	if sfxGroup and sfxGroup:IsA("SoundGroup") then
		sound.SoundGroup = sfxGroup
	end
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

-- 砍中瞬间表现：播放砍木音效并发射斧刃挂点粒子（由动画 "Event" 关键帧标记触发）
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
end

local function playAxeAction(axe: Model)
	local track = getAxeTrack(axe)
	if not track then
		return
	end
	if track.IsPlaying then
		track:Stop()
	end
	track:Play()
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
			clearWoodPile(payload.base)
			-- 本地玩家自己拾取时，在 HUD WoodAmount 上方弹出拾取飘字（明细由服务端随广播下发）
			if
				type(payload.taken) == "table"
				and payload.base:GetAttribute(AttributeEnum.OwnerId) == localPlayer.UserId
			then
				SoundService.SFX.TryOnAdd:Play()
				WoodPickupPopup.show(payload.taken)
			end
		end
	end, Network.t.table)
end

return AxeProductionController
