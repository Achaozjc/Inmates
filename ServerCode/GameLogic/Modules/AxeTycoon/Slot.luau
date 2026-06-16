--!strict

--[[
	斧头槽位（参考 dingdong 项目 Base/Slot 模式简化而来）。

	对应 AxeMachine.Floors.Floor_N 下的一个 Attachment 放置点：
	- 一个槽位最多放一把斧头模型
	- placeAxe 克隆斧头 prefab 并 PivotTo 到 attachment 世界坐标，父级为 Axes.Floor_N
	- 槽位 key 形如 "floor_index"（如 "3_7"），与持久化 AxeTycoon.axes 的键一致

	说明：本项目交互走服务端 Touched 按钮 + 服务端权威，故槽位本身不挂 ProximityPrompt/计时，
	仅负责「放置点 + 占用状态 + 模型生命周期」，比 dingdong 的 Slot 轻量很多。
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AttributeEnum = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Enums.AttributeEnum)
local handleHumanoid = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Instance.HandleHumanoid)

local Slot = {}
Slot.__index = Slot

export type ClassType = typeof(setmetatable(
	{} :: {
		_floor: number,
		_index: number,
		_attachment: Attachment,
		_axesFolder: Folder, -- 该楼层对应的 Axes.Floor_N 折叠（放置模型的父级）
		_axeCategory: string?,
		_model: Model?,
	},
	Slot
))

-- 解析斧头 prefab：优先取对应 category，缺失（高稀有度模型未做）时回退到最低级 "1"
local function resolveAxePrefab(category: string): Model?
	local instances = ReplicatedStorage:FindFirstChild("Instances")
	local prefabs = instances and instances:FindFirstChild("Prefabs")
	local axeFolder = prefabs and prefabs:FindFirstChild("Axe")
	if not axeFolder then
		return nil
	end
	local prefab = axeFolder:FindFirstChild(category) or axeFolder:FindFirstChild("1")
	if prefab and prefab:IsA("Model") then
		return prefab
	end
	return nil
end

-- 解析 DepositVFX 预制体（砍木粒子的来源，内含两个 Enabled=false 的 ParticleEmitter）
local function resolveDepositVfx(): BasePart?
	local instances = ReplicatedStorage:FindFirstChild("Instances")
	local prefabs = instances and instances:FindFirstChild("Prefabs")
	local vfxFolder = prefabs and prefabs:FindFirstChild("VFX")
	local prefab = vfxFolder and vfxFolder:FindFirstChild("DepositVFX")
	if prefab and prefab:IsA("BasePart") then
		return prefab
	end
	return nil
end

-- 砍木粒子挂点名称与相对斧刃 MeshPart 的局部偏移（对齐斧刃劈砍接触位置）
local CHOP_VFX_ATTACHMENT_NAME = "ChopVFXAttachment"
local CHOP_VFX_ATTACHMENT_CFRAME = CFrame.new(0, 3.046, -0.203)

-- 在斧刃 MeshPart（Axe.Axe）上新建 Attachment，并把 DepositVFX 下的粒子发射器克隆到其下，
-- 随模型复制到客户端，由客户端在砍木音效播放时 Emit（见 AxeProductionController）
local function attachChopEmitters(model: Model)
	local axePiece = model:FindFirstChild("Axe")
	local axeMesh = axePiece and axePiece:FindFirstChild("Axe")
	if not axeMesh or not axeMesh:IsA("BasePart") then
		return
	end
	local vfxPrefab = resolveDepositVfx()
	if not vfxPrefab then
		return
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = CHOP_VFX_ATTACHMENT_NAME
	attachment.CFrame = CHOP_VFX_ATTACHMENT_CFRAME
	for _, child in vfxPrefab:GetChildren() do
		if child:IsA("ParticleEmitter") then
			local emitter = child:Clone()
			-- 常驻挂载只用于 Emit 瞬发，确保不持续发射
			emitter.Enabled = false
			emitter.Parent = attachment
		end
	end
	attachment.Parent = axeMesh
end

function Slot.new(floor: number, index: number, attachment: Attachment, axesFolder: Folder): ClassType
	local self = setmetatable({
		_floor = floor,
		_index = index,
		_attachment = attachment,
		_axesFolder = axesFolder,
		_axeCategory = nil,
		_model = nil,
	}, Slot)
	return self
end

-- 槽位唯一键 "floor_index"
function Slot.getKey(self: ClassType): string
	return string.format("%d_%d", self._floor, self._index)
end

function Slot.getFloor(self: ClassType): number
	return self._floor
end

function Slot.getIndex(self: ClassType): number
	return self._index
end

function Slot.isOccupied(self: ClassType): boolean
	return self._model ~= nil
end

function Slot.getAxeCategory(self: ClassType): string?
	return self._axeCategory
end

function Slot.getModel(self: ClassType): Model?
	return self._model
end

-- 在槽位放置一把指定 category 的斧头：克隆 prefab、PivotTo 到 attachment、父级 Axes.Floor_N
function Slot.placeAxe(self: ClassType, category: string): boolean
	if self._model then
		-- 已占用
		return false
	end

	local prefab = resolveAxePrefab(category)
	if not prefab then
		warn(string.format("[Slot] 找不到斧头 prefab（category=%s），无法放置", category))
		return false
	end

	local model = prefab:Clone()
	model.Name = self:getKey()
	-- 写入斧头 category 属性（会复制到客户端，供 Billboard 取名/等级与决定木种）
	model:SetAttribute(AttributeEnum.Category, category)

	-- 人物 rig：以 HumanoidRootPart 作为根（PrimaryPart），保证 PivotTo 定位与锚定基准一致
	local rootPart = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if rootPart and rootPart:IsA("BasePart") then
		model.PrimaryPart = rootPart
	elseif not model.PrimaryPart then
		model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart")
	end

	-- 视觉朝向取当前方向的反方向（沿用槽位 Attachment 原始朝向）；产木/宝箱生成沿用槽位 Attachment 原始朝向（见 OriginalCFrame 属性）
	model:SetAttribute(AttributeEnum.OriginalCFrame, self._attachment.WorldCFrame)
	model:PivotTo(self._attachment.WorldCFrame)

	-- 驯服 Humanoid：关闭物理/下落/布娃娃等状态机，隐藏名字，避免大量斧子角色跑物理掉帧
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		handleHumanoid(humanoid)
	end

	-- 放置后保持静态：仅锚定根部件。其余肢体保持不锚定，由 Motor6D 关节挂在锚定根上——
	-- 既不会掉落，又能被动画驱动（若把肢体也锚定，Motor6D 不再移动它，关节动画会失效）。
	local anchorTarget = model.PrimaryPart
	if anchorTarget then
		anchorTarget.Anchored = true
	end

	-- 挂载砍木粒子发射器（客户端砍木时 Emit）
	attachChopEmitters(model)

	model.Parent = self._axesFolder

	self._model = model
	self._axeCategory = category
	return true
end

-- 清空槽位：销毁模型、复位状态
function Slot.clearAxe(self: ClassType)
	if self._model then
		self._model:Destroy()
		self._model = nil
	end
	self._axeCategory = nil
end

return Slot
