--!strict

--[[
	木头拾取飘字（HUD 2D 视觉）。

	拾取广播携带 taken（类别 → 件数）时，在 HUD 的 WoodAmount 框上方逐根弹出
	"+value" 飘字（value 取 WoodConfig 对应木种的单件价值），按稀有度着色，
	沿随机角度弹出停住后再拉回框中心渐隐回收。锚点框由 HUD 启动时通过 setAnchor 注入。

	TextLabel 实例通过 CachePool 池化复用，避免连续拾取时反复创建/销毁。
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Framework = ReplicatedStorage.ReplicatedCode.Framework
local GameLogic = ReplicatedStorage.ReplicatedCode.GameLogic

local CachePool = require(Framework.Infrastructure.CachePool)
local RarityColorConfig = require(GameLogic.Shared.Configs.RarityColorConfig)
local WoodConfig = require(GameLogic.Shared.Configs.WoodConfig)

-- CachePool 键：拾取飘字 TextLabel 专用
local POOL_KEY = "WoodPickupPopupLabel"
-- 单次拾取最多弹出的飘字条数（超出部分不弹，防一次背走数百根时 UI 爆炸）
local MAX_POPUPS_PER_PICKUP = 25
-- 逐条弹出的间隔（秒），营造连续跳字的节奏
local EMIT_INTERVAL = 0.06
-- 两段式动画：弹出（减速停住）→ 短暂停留 → 拉回框中心（加速）并渐隐
local POP_TIME = 0.5
local HOLD_TIME = 0.2
local PULL_TIME = 0.5
-- 拉回终点（锚点框局部坐标，即 WoodAmount 框中心）
local PULL_TARGET = UDim2.fromScale(0.5, 0.5)
-- 弹射距离范围（相对锚点框高度的倍数，按像素换算，避免横向被框宽放大）
local FLY_DIST_MIN = 1.0
local FLY_DIST_MAX = 1.8
-- 弹射角度散布：以竖直向上为基准，左右各偏最多此角度（弧度）
local FLY_ANGLE_RANGE = math.rad(70)
-- 飘字基础尺寸（相对锚点框）；字号随数值增大，最高放大到基础的 MAX_SIZE_SCALE 倍
local LABEL_SIZE = UDim2.fromScale(0.6, 0.55)
local MAX_SIZE_SCALE = 2
-- 起始位置散布范围（相对锚点框：X 居中小幅散布，Y 紧贴框顶）
local START_X_MIN = 0.35
local START_X_MAX = 0.65
local START_Y_MIN = -0.05
local START_Y_MAX = -0.15

local POP_INFO = TweenInfo.new(POP_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PULL_INFO = TweenInfo.new(PULL_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local WoodPickupPopup = {}

-- 配置中的最高稀有度（value 随稀有度指数增长，故按稀有度线性映射字号 ≈ 按 log(value) 映射）
local MAX_RARITY = 1
for _, info in WoodConfig.Woods do
	if info.rarity > MAX_RARITY then
		MAX_RARITY = info.rarity
	end
end

-- 稀有度 → 字号缩放：最低 1 倍，最高 MAX_SIZE_SCALE 倍
local function getSizeScale(rarity: number): number
	local alpha = (rarity - 1) / math.max(1, MAX_RARITY - 1)
	return 1 + math.clamp(alpha, 0, 1) * (MAX_SIZE_SCALE - 1)
end

-- HUD 注入的锚点框（WoodAmount），飘字挂在其下、相对它定位
local anchorFrame: Frame? = nil
-- 单条飘字弹出时回调（由 HUD 注入，用于播放弹射音效等）
local onPop: (() -> ())? = nil
-- 池空时克隆用的模板（不挂入 DataModel，仅作 Clone 源）
local template: TextLabel? = nil

local function getTemplate(): TextLabel
	if template then
		return template
	end

	local label = Instance.new("TextLabel")
	label.Name = "WoodPickupPopup"
	label.Size = LABEL_SIZE
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.BackgroundTransparency = 1
	label.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold, Enum.FontStyle.Normal)
	label.TextScaled = true
	label.ZIndex = 10
	label.Text = ""

	local stroke = Instance.new("UIStroke")
	stroke.Name = "Stroke"
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = 2
	stroke.Parent = label

	template = label
	return label
end

-- HUD 启动时注入 WoodAmount 框作为飘字锚点
function WoodPickupPopup.setAnchor(frame: Frame)
	anchorFrame = frame
end

function WoodPickupPopup.setOnPop(callback: () -> ())
	onPop = callback
end

-- 弹出单条飘字：从池中取实例 → 重置状态 → 上浮渐隐 → 回收入池
local function popOne(parent: Frame, text: string, color: Color3, sizeScale: number)
	local label = CachePool.getObject(POOL_KEY, getTemplate())
	if not label:IsA("TextLabel") then
		label:Destroy()
		return
	end
	local stroke = label:FindFirstChild("Stroke")

	-- 复用实例须重置上一轮 tween 留下的终态
	label.Text = text
	label.TextColor3 = color
	label.TextTransparency = 0
	-- 字号随数值放大（TextScaled 跟随框尺寸缩放）
	label.Size = UDim2.fromScale(LABEL_SIZE.X.Scale * sizeScale, LABEL_SIZE.Y.Scale * sizeScale)
	if stroke and stroke:IsA("UIStroke") then
		stroke.Transparency = 0
	end

	local startX = START_X_MIN + math.random() * (START_X_MAX - START_X_MIN)
	local startY = START_Y_MIN + math.random() * (START_Y_MAX - START_Y_MIN)
	label.Position = UDim2.fromScale(startX, startY)
	label.Parent = parent

	-- 随机弹射方向：以竖直向上为基准左右散开；位移按框高像素换算，
	-- 叠加在起始 Scale 位置的 Offset 分量上，避免 X 方向被框宽比例放大
	local angle = (math.random() * 2 - 1) * FLY_ANGLE_RANGE
	local distance = (FLY_DIST_MIN + math.random() * (FLY_DIST_MAX - FLY_DIST_MIN)) * parent.AbsoluteSize.Y
	local goalPosition = UDim2.new(
		startX,
		math.sin(angle) * distance,
		startY,
		-math.cos(angle) * distance
	)

	-- 第一段：弹出到随机落点（减速停住），不褪色
	local popTween = TweenService:Create(label, POP_INFO, { Position = goalPosition })
	-- 第二段：拉回框中心（加速），同时渐隐
	local pullTween = TweenService:Create(label, PULL_INFO, {
		Position = PULL_TARGET,
		TextTransparency = 1,
	})
	local strokePullTween = if stroke and stroke:IsA("UIStroke")
		then TweenService:Create(stroke, PULL_INFO, { Transparency = 1 })
		else nil

	popTween.Completed:Once(function(state)
		if state ~= Enum.PlaybackState.Completed then
			return
		end
		task.delay(HOLD_TIME, function()
			-- 停留期间实例可能随 HUD 销毁，失效则跳过（不入池）
			if not label:IsDescendantOf(game) then
				return
			end
			pullTween.Completed:Once(function()
				CachePool.freeObject(POOL_KEY, label)
			end)
			pullTween:Play()
			if strokePullTween then
				strokePullTween:Play()
			end
		end)
	end)
	if onPop then
		onPop()
	end
	popTween:Play()
end

-- 按拾取明细逐根弹出飘字：每根木头一条 "+value"，按稀有度着色、降序依次弹出
function WoodPickupPopup.show(taken: { [string]: number })
	local parent = anchorFrame
	if not parent then
		return
	end

	-- 收集有效类别（随后按稀有度降序排列，高价值先弹）
	type Entry = { count: number, text: string, color: Color3, sizeScale: number }
	local rarities: { number } = {}
	local entryByRarity: { [number]: Entry } = {}
	for category, count in taken do
		local pieceCount = tonumber(count) or 0
		local info = WoodConfig.Woods[category]
		if pieceCount > 0 and info then
			rarities[#rarities + 1] = info.rarity
			entryByRarity[info.rarity] = {
				count = pieceCount,
				text = "+" .. WoodConfig.formatWoodQuantity(info.value),
				color = RarityColorConfig.getColor(info.rarity),
				sizeScale = getSizeScale(info.rarity),
			}
		end
	end
	if #rarities == 0 then
		return
	end
	-- 稀有度降序：大数值优先弹出，封顶截断时也优先保留高价值飘字
	table.sort(rarities, function(a, b)
		return a > b
	end)

	-- 逐根展开为弹出序列，封顶 MAX_POPUPS_PER_PICKUP
	local emitted = 0
	for _, rarity in rarities do
		local entry = entryByRarity[rarity]
		for _ = 1, entry.count do
			if emitted >= MAX_POPUPS_PER_PICKUP then
				return
			end
			if emitted == 0 then
				popOne(parent, entry.text, entry.color, entry.sizeScale)
			else
				local text, color, sizeScale = entry.text, entry.color, entry.sizeScale
				task.delay(emitted * EMIT_INTERVAL, function()
					-- 延迟期间 HUD 可能被销毁重建，锚点失效则跳过
					if parent:IsDescendantOf(game) then
						popOne(parent, text, color, sizeScale)
					end
				end)
			end
			emitted += 1
		end
	end
end

return WoodPickupPopup
