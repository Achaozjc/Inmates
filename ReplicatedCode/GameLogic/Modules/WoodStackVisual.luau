--!strict

--[[
	木材堆叠视觉（端共享）：堆叠区 WoodPile 与角色背负共用同一套网格与预制件逻辑。
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WoodStackVisual = {}

-- 堆叠区网格：4 列 ×6 排（4×6=24/层）。新木材模型约 4(长X) × 1.54(高Y) × 1.54(宽Z)。
-- 原木沿局部 X 轴躺放，故列(col→X)按长度方向间距、排(row→Z)按宽度方向间距，避免重叠又留小间隙。
WoodStackVisual.STACK_COLUMNS = 4
WoodStackVisual.STACK_ROWS = 6
WoodStackVisual.WOOD_STEP_X = 4.25 -- 沿原木长轴(~4)的列间距，留约 0.25 间隙
WoodStackVisual.WOOD_STEP_Z = 1.74 -- 沿原木宽度(~1.54)的排间距，留约 0.2 间隙
WoodStackVisual.LAYER_HEIGHT = 1.6 -- 层高(木材高~1.54)，留约 0.06 间隙
WoodStackVisual.GROUND_BASE_HEIGHT_OFFSET = 5

function WoodStackVisual.resolvePrefab(category: string): Model?
	local instances = ReplicatedStorage:FindFirstChild("Instances")
	local prefabs = instances and instances:FindFirstChild("Prefabs")
	local woodFolder = prefabs and prefabs:FindFirstChild("Wood")
	if not woodFolder then
		return nil
	end
	local prefab = woodFolder:FindFirstChild(category) or woodFolder:FindFirstChild("1")
	if prefab and prefab:IsA("Model") then
		return prefab
	end
	return nil
end

-- slotIndex 从 0 起，与堆叠区 getNextStackCFrame 使用相同网格
-- columns/rows 可选：缺省时用堆叠区 4×6 网格；角色背负传入 1×3 等紧凑网格
-- stepX/stepZ 可选：缺省用堆叠区列/排间距；背负可传入更紧凑的间距独立调节
function WoodStackVisual.getGridOffset(
	slotIndex: number,
	baseHeightOffset: number,
	columns: number?,
	rows: number?,
	stepX: number?,
	stepZ: number?
): Vector3
	local cols = columns or WoodStackVisual.STACK_COLUMNS
	local rws = rows or WoodStackVisual.STACK_ROWS
	local sx = stepX or WoodStackVisual.WOOD_STEP_X
	local sz = stepZ or WoodStackVisual.WOOD_STEP_Z

	local col = slotIndex % cols
	local row = math.floor(slotIndex / cols) % rws
	local layer = math.floor(slotIndex / (cols * rws))

	return Vector3.new(
		(col - (cols - 1) / 2) * sx,
		layer * WoodStackVisual.LAYER_HEIGHT + WoodStackVisual.LAYER_HEIGHT / 2 + baseHeightOffset,
		(row - (rws - 1) / 2) * sz
	)
end

function WoodStackVisual.prepareStaticModel(model: Model)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
		end
	end
end

-- 设置为物理滚动态：木材不锚定，靠 RootPart（球体）碰撞顺轨道滚动
-- 视觉部件焊接在 RootPart 上并设为无质量，让整模型以 RootPart 为主体滚动
function WoodStackVisual.preparePhysicalModel(model: Model)
	local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			if part == primary then
				part.CanCollide = true
				part.CanTouch = true
				part.CanQuery = false
			else
				part.CanCollide = false
				part.CanTouch = false
				part.CanQuery = false
				part.Massless = true
			end
		end
	end
end

function WoodStackVisual.prepareWeldedModel(model: Model)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.Massless = true
		end
	end
end

function WoodStackVisual.weldModelToPart(model: Model, hostPart: BasePart)
	local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if not primary then
		return
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hostPart
	weld.Part1 = primary
	weld.Parent = primary
end

return WoodStackVisual
