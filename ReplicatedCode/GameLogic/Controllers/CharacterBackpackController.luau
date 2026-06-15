--!strict

--[[
	角色背部木头视觉控制器（纯客户端）。

	与堆叠区 WoodPile 共用 WoodStackVisual 预制件与层叠间距；背负堆叠改用更紧凑的
	1×3 网格（见 BACK_STACK_COLUMNS/ROWS），不再沿用堆叠区 5×5。

	背负模型为锚定纯视觉部件，不焊接、不进角色物理装配；每帧用 BulkMoveTo
	按躯干 CFrame 整批跟随。这样部件数量只影响渲染，不增加物理开销。
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Framework = ReplicatedStorage.ReplicatedCode.Framework
local GameLogic = ReplicatedStorage.ReplicatedCode.GameLogic

local PlayerDataClient = require(Framework.DataStore.PlayerDataClient)
local LocalCharacter = require(GameLogic.Modules.LocalCharacter)
local WoodStackVisual = require(GameLogic.Modules.WoodStackVisual)
local AttributeEnum = require(GameLogic.Shared.Enums.AttributeEnum)
local PlayerDataKey = require(GameLogic.SharedConstants.Keys.PlayerDataKey)

local localPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() :: Player

local BACK_ATTACHMENT_NAME = "WoodCarryAttachment"
local VISUAL_FOLDER_NAME = "CarriedWoodVisual"
local BACK_OFFSET = CFrame.new(0, 0.15, 2.2)
-- 背负堆叠网格：1 列 ×2 排（每层 2 根并排，叠满后向上堆层），收窄以落在背架托盘内
local BACK_STACK_COLUMNS = 1
local BACK_STACK_ROWS = 2
-- 木材换模型后变小（宽~1.54），背负排间距随之收紧，原木紧贴只留极小间隙
local BACK_STACK_STEP = 1.65
-- 背负时绕 Y 轴翻转，使堆叠朝向与堆叠区一致地贴在背上
local BACK_PILE_ROTATION = CFrame.Angles(0, math.pi, 0)
-- 背负视觉数量上限：锚定部件无物理开销，仅渲染成本，可放宽；防 carrying 无限累积失控
local MAX_VISUAL_PIECES = 300
-- 背架装饰预制件名（ReplicatedStorage/Instances/Prefabs/Rack），背上有木头时显示
local RACK_PREFAB_NAME = "Rack"
-- 背架相对躯干的落位：立柱侧贴背、托盘向后伸，托盘面与第一层木材底面对齐（Studio 内可视化调参所得）
local RACK_OFFSET = CFrame.new(0, 0.9, 1.8)
-- 与 AxeProductionController 一致的地面堆路径常量（重建时直接复用地面模型，免克隆）
local AXE_MACHINE_NAME = "InmateMachine"
local STACKING_TRIGGER_NAME = "TouchedStacking"
local WOOD_PILE_FOLDER_NAME = "WoodPile"
-- 过继池兜底清理延迟（秒）：拾取广播与数据同步通常同帧到达，1 秒足够覆盖乱序
local ADOPT_POOL_DRAIN_DELAY = 1
-- 兜底清理时每帧销毁的模型数（分帧摊销，避免批量 Destroy 尖峰）
local DESTROY_PER_FRAME = 20

-- 单根背负木材的渲染记录：类别 + 模型 + 各部件相对躯干的 CFrame（跟随用）
type PieceRecord = {
	category: string,
	model: Model,
	parts: { BasePart },
	offsets: { CFrame },
}

local CharacterBackpackController = {
	Name = "CharacterBackpackController",
	_started = false,
	_visualFolder = nil :: Folder?,
	_attachment = nil :: Attachment?,
	_torso = nil :: BasePart?,
	-- 当前已渲染的槽位记录（slot→PieceRecord），用于增量比对，避免整夹重建
	_renderedPieces = {} :: { PieceRecord },
	-- BulkMoveTo 用的扁平数组（所有槽位部件 / 相对躯干偏移，与 _renderedPieces 同步重建）
	_bulkParts = {} :: { BasePart },
	_bulkOffsets = {} :: { CFrame },
	_followConnection = nil :: RBXScriptConnection?,
	-- 背架装饰部件（背上有木头时显示，背空时移除），随躯干 BulkMoveTo 跟随
	_rackPart = nil :: BasePart?,
	-- 过继池：拾取广播先于数据同步到达时，地面堆模型暂存于此等重建消费（category → models）
	_adoptPool = {} :: { [string]: { Model } },
	_adoptDrainGen = 0,
	-- 过继模型暂存文件夹（仍在 Workspace 下，避免离开 DataModel 触发渲染重建开销）
	_holdingFolder = nil :: Folder?,
}

-- 从列表尾部取出一个模型（取不到返回 nil）
local function takeLast(list: { Model }?): Model?
	if not list then
		return nil
	end
	local n = #list
	if n == 0 then
		return nil
	end
	local model = list[n]
	list[n] = nil
	return model
end

-- 收集本地玩家基地地面堆中可复用的模型（category → models）。
-- 数据同步先于拾取广播到达时，重建走此路径直接「拉」现成模型，免克隆。
local function collectGroundPile(): { [string]: { Model } }
	local result: { [string]: { Model } } = {}
	local world = Workspace:FindFirstChild("World")
	if not world then
		return result
	end
	for _, child in world:GetChildren() do
		if
			string.match(child.Name, "^Base_%d+$")
			and child:GetAttribute(AttributeEnum.OwnerId) == localPlayer.UserId
		then
			local axeMachine = child:FindFirstChild(AXE_MACHINE_NAME)
			local anchor = axeMachine and axeMachine:FindFirstChild(STACKING_TRIGGER_NAME)
			local pile = anchor and anchor:FindFirstChild(WOOD_PILE_FOLDER_NAME)
			if pile then
				-- 地面堆模型以木种类别命名（克隆自同名预制体）
				for _, model in pile:GetChildren() do
					if model:IsA("Model") then
						local list = result[model.Name]
						if not list then
							list = {}
							result[model.Name] = list
						end
						list[#list + 1] = model
					end
				end
			end
			break
		end
	end
	return result
end

-- 收集背负木材逐根类别列表；按类别排序保证渲染顺序稳定，使增量比对可靠；
-- 总数封顶到 MAX_VISUAL_PIECES，防止 carrying 无上限累积导致部件无限增长。
local function buildVisualCategories(carrying: { [string]: number }): { string }
	local categories: { string } = {}
	for category in carrying do
		categories[#categories + 1] = category
	end
	table.sort(categories)

	local pieces: { string } = {}
	for _, category in categories do
		local pieceCount = tonumber(carrying[category]) or 0
		for _ = 1, pieceCount do
			if #pieces >= MAX_VISUAL_PIECES then
				return pieces
			end
			pieces[#pieces + 1] = category
		end
	end
	return pieces
end

local function getTorso(character: Model): BasePart?
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart and rootPart:IsA("BasePart") then
		return rootPart
	end
	return nil
end

function CharacterBackpackController:ensureBackAttachment(character: Model): (Attachment?, Folder?)
	local torso = getTorso(character)
	if not torso then
		return nil, nil
	end

	local attachment = torso:FindFirstChild(BACK_ATTACHMENT_NAME)
	if not attachment or not attachment:IsA("Attachment") then
		if attachment then
			attachment:Destroy()
		end
		local newAttachment = Instance.new("Attachment")
		newAttachment.Name = BACK_ATTACHMENT_NAME
		newAttachment.CFrame = BACK_OFFSET
		newAttachment.Parent = torso
		attachment = newAttachment
	end

	local folder = character:FindFirstChild(VISUAL_FOLDER_NAME)
	if not folder or not folder:IsA("Folder") then
		if folder then
			folder:Destroy()
		end
		local newFolder = Instance.new("Folder")
		newFolder.Name = VISUAL_FOLDER_NAME
		newFolder.Parent = character
		folder = newFolder
	end

	self._attachment = attachment :: Attachment
	self._visualFolder = folder :: Folder
	self._torso = torso
	return self._attachment, self._visualFolder
end

-- 获取一根可用木材模型：过继池 → 地面堆 → 克隆。前两者复用现成实例（仅改父级），
-- 避免一次性拾取大量木材时批量克隆造成的单帧尖峰。
function CharacterBackpackController:_acquireModel(category: string, groundPool: { [string]: { Model } }): Model?
	local reused = takeLast(self._adoptPool[category]) or takeLast(groundPool[category])
	if reused then
		return reused
	end
	local prefab = WoodStackVisual.resolvePrefab(category)
	if not prefab then
		return nil
	end
	return prefab:Clone()
end

-- 装配单根背负木材（锚定纯视觉），记录各部件相对躯干的偏移供 BulkMoveTo 跟随
function CharacterBackpackController:_buildPiece(
	folder: Folder,
	torso: BasePart,
	index: number,
	category: string,
	groundPool: { [string]: { Model } }
): PieceRecord?
	local wood = self:_acquireModel(category, groundPool)
	if not wood then
		return nil
	end

	wood.Name = tostring(index)
	-- 复用模型已是静态态，重复设置幂等且开销极小，统一调用保证克隆路径正确
	WoodStackVisual.prepareStaticModel(wood)

	local gridOffset = WoodStackVisual.getGridOffset(
		index - 1,
		0,
		BACK_STACK_COLUMNS,
		BACK_STACK_ROWS,
		BACK_STACK_STEP,
		BACK_STACK_STEP
	)
	-- 躯干局部空间中的落位：背部偏移 → 翻转 → 网格槽位
	local pivotOffset = BACK_OFFSET * BACK_PILE_ROTATION * CFrame.new(gridOffset)
	wood:PivotTo(torso.CFrame * pivotOffset)
	wood.Parent = folder

	-- 记录每个部件相对躯干的 CFrame，跟随时整批换算
	local parts: { BasePart } = {}
	local offsets: { CFrame } = {}
	local torsoCF = torso.CFrame
	for _, part in wood:GetDescendants() do
		if part:IsA("BasePart") then
			parts[#parts + 1] = part
			offsets[#offsets + 1] = torsoCF:ToObjectSpace(part.CFrame)
		end
	end

	return {
		category = category,
		model = wood,
		parts = parts,
		offsets = offsets,
	}
end

-- 解析背架预制件（单个 MeshPart：ReplicatedStorage/Instances/Prefabs/Rack）
local function resolveRackPrefab(): BasePart?
	local instances = ReplicatedStorage:FindFirstChild("Instances")
	local prefabs = instances and instances:FindFirstChild("Prefabs")
	local rack = prefabs and prefabs:FindFirstChild(RACK_PREFAB_NAME)
	if rack and rack:IsA("BasePart") then
		return rack
	end
	return nil
end

-- 确保背架装饰存在（背上有木头时调用）；锚定纯视觉，随后由 BulkMoveTo 跟随
function CharacterBackpackController:_ensureRackVisual(folder: Folder, torso: BasePart)
	local existing = self._rackPart
	if existing and existing.Parent == folder then
		return
	end

	local prefab = resolveRackPrefab()
	if not prefab then
		return
	end

	local rack = prefab:Clone()
	rack.Anchored = true
	rack.CanCollide = false
	rack.CanTouch = false
	rack.CanQuery = false
	rack.CFrame = torso.CFrame * RACK_OFFSET
	rack.Parent = folder
	self._rackPart = rack
end

-- 移除背架装饰（背空时调用）
function CharacterBackpackController:_removeRackVisual()
	local rack = self._rackPart
	if rack then
		rack:Destroy()
		self._rackPart = nil
	end
end

-- 将所有槽位的部件/偏移压平为 BulkMoveTo 用的两个数组
function CharacterBackpackController:_rebuildBulkArrays()
	local bulkParts: { BasePart } = {}
	local bulkOffsets: { CFrame } = {}
	local rack = self._rackPart
	if rack then
		bulkParts[#bulkParts + 1] = rack
		bulkOffsets[#bulkOffsets + 1] = RACK_OFFSET
	end
	for _, record in self._renderedPieces do
		for i, part in record.parts do
			bulkParts[#bulkParts + 1] = part
			bulkOffsets[#bulkOffsets + 1] = record.offsets[i]
		end
	end
	self._bulkParts = bulkParts
	self._bulkOffsets = bulkOffsets
end

-- 每帧按躯干 CFrame 整批移动背负部件（锚定部件，无物理参与）
function CharacterBackpackController:_onFollowStep()
	local torso = self._torso
	local bulkParts = self._bulkParts
	if not torso or #bulkParts == 0 then
		return
	end

	local torsoCF = torso.CFrame
	local targets = table.create(#bulkParts)
	local offsets = self._bulkOffsets
	for i = 1, #bulkParts do
		targets[i] = torsoCF * offsets[i]
	end
	Workspace:BulkMoveTo(bulkParts, targets, Enum.BulkMoveMode.FireCFrameChanged)
end

function CharacterBackpackController:_ensureFollowLoop()
	if self._followConnection then
		return
	end
	self._followConnection = RunService.RenderStepped:Connect(function()
		self:_onFollowStep()
	end)
end

function CharacterBackpackController:_stopFollowLoop()
	if self._followConnection then
		self._followConnection:Disconnect()
		self._followConnection = nil
	end
end

-- 增量重建背负视觉：保留已有槽位，仅克隆新增木材；随后刷新跟随数组
function CharacterBackpackController:rebuildVisuals(carrying: { [string]: number })
	local folder = self._visualFolder
	local torso = self._torso
	if not folder or not torso then
		return
	end

	local newPieces = buildVisualCategories(carrying)
	local rendered = self._renderedPieces

	-- 背架装饰：背上有木头时显示，背空时移除
	if #newPieces > 0 then
		self:_ensureRackVisual(folder, torso)
	else
		self:_removeRackVisual()
	end

	-- 移除多出的、或类别与新列表不一致的旧槽位（其余原样保留，不重建）
	local oldCount = #rendered
	for index = oldCount, 1, -1 do
		local record = rendered[index]
		if record and (index > #newPieces or record.category ~= newPieces[index]) then
			record.model:Destroy()
			rendered[index] = nil
		end
	end

	-- 仅填充空缺槽位（拾取场景下即新增部分）；需要新建时才收集地面堆复用池
	local groundPool: { [string]: { Model } }? = nil
	for index = 1, #newPieces do
		if rendered[index] == nil then
			if not groundPool then
				groundPool = collectGroundPile()
			end
			rendered[index] = self:_buildPiece(folder, torso, index, newPieces[index], groundPool :: { [string]: { Model } })
		end
	end

	self:_rebuildBulkArrays()
	if #self._bulkParts > 0 then
		self:_ensureFollowLoop()
	else
		self:_stopFollowLoop()
	end
end

function CharacterBackpackController:_ensureHoldingFolder(): Folder
	local existing = self._holdingFolder
	if existing then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "CarriedWoodAdoptPool"
	-- 故意不挂入 DataModel：过继的剩余模型立即从画面消失（等同旧版瞬间清空的观感），
	-- 实例仅在内存中保留待消费；兜底销毁时也无渲染开销
	self._holdingFolder = folder
	return folder
end

-- 分帧销毁过继池剩余模型（超出视觉上限 / 数据迟迟未到的兜底），避免批量 Destroy 尖峰
function CharacterBackpackController:_drainAdoptPool()
	local pool = self._adoptPool
	self._adoptPool = {}
	task.spawn(function()
		local count = 0
		for _, list in pool do
			for _, model in list do
				model:Destroy()
				count += 1
				if count % DESTROY_PER_FRAME == 0 then
					task.wait()
				end
			end
		end
	end)
end

-- 拾取广播到达时由 AxeProductionController 调用：将地面堆模型整体过继到池中，
-- 重建（carrying 数据同步）时优先消费这些现成实例，免销毁 + 免克隆。
-- 拾取广播与数据同步的到达顺序不保证，此为「广播先到」的承接路径；
-- 「数据先到」时重建会直接从地面堆拉取（见 collectGroundPile），届时此处收到的是剩余部分。
function CharacterBackpackController:adoptModels(models: { Model })
	-- 先尝试消费：数据若已先到，重建会直接从地面堆拉取，模型全程留在 Workspace 内
	-- （不经过隐藏池，避免脱离再重入 DataModel 的渲染重建开销）
	self:refreshFromData()

	local holding = self:_ensureHoldingFolder()
	local pool = self._adoptPool
	for _, model in models do
		-- 已被上面的重建消费（挪入背负文件夹）的跳过，只暂存真正的剩余
		if model.Parent == self._visualFolder then
			continue
		end
		-- 地面堆模型以木种类别命名
		local list = pool[model.Name]
		if not list then
			list = {}
			pool[model.Name] = list
		end
		list[#list + 1] = model
		-- 挪入隐藏暂存文件夹：画面上立即消失，且不会被源文件夹清空连带销毁
		model.Parent = holding
	end

	-- 兜底：短暂延迟后清掉未被消费的剩余（一般是超出 MAX_VISUAL_PIECES 的部分）
	self._adoptDrainGen += 1
	local gen = self._adoptDrainGen
	task.delay(ADOPT_POOL_DRAIN_DELAY, function()
		if gen ~= self._adoptDrainGen then
			return
		end
		self:_drainAdoptPool()
	end)
end

function CharacterBackpackController:refreshFromData()
	if not PlayerDataClient.hasLoaded() then
		return
	end

	local axeTycoon = PlayerDataClient.get(PlayerDataKey.AxeTycoon)
	local carrying = if type(axeTycoon) == "table" and type(axeTycoon.carrying) == "table"
		then axeTycoon.carrying
		else {}

	self:rebuildVisuals(carrying)
end

-- LocalCharacter.added 在角色死亡时会以 nil 触发（见 LocalCharacter._onDead），
-- 此时仅清空状态停掉跟随；重生后会再次携带新角色触发，届时重建视觉
function CharacterBackpackController:onCharacterAdded(character: Model?)
	self:_stopFollowLoop()
	self._attachment = nil
	self._visualFolder = nil
	self._torso = nil
	-- 旧角色的背架随旧视觉文件夹销毁，这里只清引用即可
	self._rackPart = nil
	-- 新角色对应新的空视觉文件夹，清空渲染快照与跟随数组，避免增量比对错配旧槽位
	self._renderedPieces = {}
	self._bulkParts = {}
	self._bulkOffsets = {}
	if not character then
		return
	end
	self:ensureBackAttachment(character)
	self:refreshFromData()
end

function CharacterBackpackController:init()
	if self._started then
		return
	end
	self._started = true

	task.spawn(function()
		if not PlayerDataClient.hasLoaded() then
			PlayerDataClient.loaded:Wait()
		end

		LocalCharacter.added:Connect(function(character: Model?)
			self:onCharacterAdded(character)
		end)

		if LocalCharacter.character then
			self:onCharacterAdded(LocalCharacter.character)
		end

		PlayerDataClient.getUpdateSignal(PlayerDataKey.AxeTycoon):Connect(function()
			self:refreshFromData()
		end)
	end)
end

return CharacterBackpackController
