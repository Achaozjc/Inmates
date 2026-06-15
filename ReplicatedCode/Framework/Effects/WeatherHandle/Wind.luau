--!strict
-- Wind.luau
-- 风天特效处理器：Trail 风线在镜头周围绵长飘过，模拟微风拂面感。
-- 以 Camera 为中心生成，无论镜头推拉都自然；
-- 双轴正弦（垂向 + 侧向）让轨迹呈真 S 形曲线。

local RunService = game:GetService("RunService")
local Workspace  = game:GetService("Workspace")

local CurrentCamera = Workspace.CurrentCamera :: Camera

-- ── 参数（可按需调整） ─────────────────────────────────────────────────────
local MAX_STREAKS    = 14      -- 同屏最大风线数
local SPAWN_INTERVAL = 0.26    -- 生成间隔（秒），更密一点让节奏更连续
local LIFETIME_MIN   = 5.8     -- 风线最短存活（秒）
local LIFETIME_MAX   = 6.4     -- 风线最长存活（秒），收窄随机区间让体感更规律
local RANGE          = 38     -- 镜头周围生成半径（studs）
local SPEED          = 10     -- 主方向速度（studs/秒）
local AMPLITUDE      = 0.48   -- 正弦波振幅（越大弧度越夸张）
local FREQ           = 1.30   -- 正弦波周期（秒/周期，越大波长越长）
-- 双轴系数：横向弧度 = 垂直方向的 0.45 倍，周期稍长，制造立体 S 形
local HORIZ_RATIO    = 0.45
local HORIZ_FREQ_MUL = 1.55

local TRAIL_LIFETIME = 1.90   -- Trail 段存活时间（决定风线长度）：更长、更有"起风"拉丝感
-- 风线粗细由两 Attachment 间距（0.08 studs）× WidthScale 决定，无需额外 Width 属性
local TRAIL_COLOR    = Color3.fromRGB(208, 220, 246) -- 淡蓝白

-- ── 状态 ─────────────────────────────────────────────────────────────────
local Wind = {}
Wind.enabled = false

local spawnThread: thread? = nil
local container: Folder?   = nil

-- ── 池化：单 RenderStepped 驱动所有活跃风线 ─────────────────────────────

type StreakEntry = {
	part: Part,
	dir: Vector3,
	perp: Vector3,
	phase: number,
	expireAt: number,
}

local activeStreaks: { StreakEntry } = {}
local renderConn: RBXScriptConnection? = nil

-- ── 内部工具 ──────────────────────────────────────────────────────────────

local function randomDir2D(): Vector3
	local a = math.random() * math.pi * 2
	return Vector3.new(math.cos(a), 0, math.sin(a))
end

local function makeStreakPart(parent: Instance): Part
	local p        = Instance.new("Part")
	p.Size         = Vector3.new(0.05, 0.05, 0.05)
	p.Transparency = 1
	p.Anchored     = true
	p.CanCollide   = false
	p.CanQuery     = false
	p.CanTouch     = false
	p.CastShadow   = false
	p.Archivable   = false
	p.Parent       = parent

	local att0      = Instance.new("Attachment")
	att0.Position   = Vector3.new(0, 0.04, 0)
	att0.Parent     = p

	local att1      = Instance.new("Attachment")
	att1.Position   = Vector3.new(0, -0.04, 0)
	att1.Parent     = p

	local t             = Instance.new("Trail")
	t.Attachment0       = att0
	t.Attachment1       = att1
	t.Lifetime          = TRAIL_LIFETIME
	t.MinLength         = 0
	t.FaceCamera        = true
	t.LightEmission     = 0.05
	t.LightInfluence    = 0.88
	t.Color             = ColorSequence.new(TRAIL_COLOR)
	-- 两端渐尖，中间饱满 —— 形成"飘带"轮廓
	t.WidthScale        = NumberSequence.new({
		NumberSequenceKeypoint.new(0,    0),
		NumberSequenceKeypoint.new(0.12, 1),
		NumberSequenceKeypoint.new(0.88, 1),
		NumberSequenceKeypoint.new(1,    0),
	})
	-- 中段最清晰，两端自然淡出
	t.Transparency      = NumberSequence.new({
		NumberSequenceKeypoint.new(0,    1),
		NumberSequenceKeypoint.new(0.12, 0.20),
		NumberSequenceKeypoint.new(0.88, 0.20),
		NumberSequenceKeypoint.new(1,    1),
	})
	t.Archivable        = false
	t.Parent            = p

	return p
end

local function spawnStreak()
	if #activeStreaks >= MAX_STREAKS then return end
	if not container then return end

	local part = makeStreakPart(container)
	local camPos = CurrentCamera.CFrame.Position

	part.Position = camPos + Vector3.new(
		(math.random() * 2 - 1) * RANGE,
		math.random() * RANGE * 0.50,
		(math.random() * 2 - 1) * RANGE
	)

	local dir   = randomDir2D()
	local perp  = Vector3.new(-dir.Z, 0, dir.X)
	local phase = math.random() * math.pi * 2
	local lifetime = LIFETIME_MIN + math.random() * (LIFETIME_MAX - LIFETIME_MIN)

	table.insert(activeStreaks, {
		part = part,
		dir = dir,
		perp = perp,
		phase = phase,
		expireAt = os.clock() + lifetime,
	})
end

local function connectRenderLoop()
	if renderConn then return end

	renderConn = RunService.RenderStepped:Connect(function(dt: number)
		local now = os.clock()
		local i = 1
		while i <= #activeStreaks do
			local entry = activeStreaks[i]

			if now >= entry.expireAt then
				-- Trail 自然消散后销毁 Part
				task.delay(TRAIL_LIFETIME + 0.08, function()
					entry.part:Destroy()
				end)
				local n = #activeStreaks
				activeStreaks[i] = activeStreaks[n]
				activeStreaks[n] = nil
				continue
			end

			local waveY = AMPLITUDE * math.sin(now / FREQ + entry.phase)
			local waveH = AMPLITUDE * HORIZ_RATIO
				* math.sin(now / (FREQ * HORIZ_FREQ_MUL) + entry.phase + 1.2)

			entry.part.Position += entry.dir * (SPEED * dt)
				+ entry.perp            * (waveH * dt * 10)
				+ Vector3.new(0, 1, 0)  * (waveY * dt * 10)

			i += 1
		end
	end)
end

local function disconnectRenderLoop()
	if renderConn then
		renderConn:Disconnect()
		renderConn = nil
	end
end

local function clearAllStreaks()
	for _, entry in ipairs(activeStreaks) do
		entry.part:Destroy()
	end
	table.clear(activeStreaks)
end

local function startLoop()
	spawnThread = task.spawn(function()
		while Wind.enabled do
			spawnStreak()
			task.wait(SPAWN_INTERVAL)
		end
	end)
end

-- ── 公共接口 ──────────────────────────────────────────────────────────────

function Wind:Enable(_tweenInfo: TweenInfo?)
	if Wind.enabled then return end
	Wind.enabled = true

	local f      = Instance.new("Folder")
	f.Name       = "__WindStreaks"
	f.Archivable = false
	f.Parent     = Workspace
	container    = f

	connectRenderLoop()
	startLoop()
end

function Wind:Disable(_tweenInfo: TweenInfo?)
	if not Wind.enabled then return end
	Wind.enabled = false

	if spawnThread then
		task.cancel(spawnThread)
		spawnThread = nil
	end

	disconnectRenderLoop()
	clearAllStreaks()

	if container then
		container:Destroy()
		container = nil
	end
end

function Wind:SetIntensityRatio(_val: number, _tweenInfo: TweenInfo?) end

return Wind
