--!strict
-- Tornado.luau
-- 龙卷风特效处理器（纯 Trail 涡流，无模型）：
--   视觉 —— Trail 碎屑以极坐标切线方向围绕镜头做差速旋转：
--            内圈比外圈转速更快（线速度固定 → 内圈角速度大），产生真实涡旋视觉；
--            缓慢向内收拢 + 向上漂移，模拟被吸入高空的感觉；
--            叠加随机扰动，打破规则圆形，更接近真实乱流。
--   音效 —— 循环风声渐入渐出

local Workspace    = game:GetService("Workspace")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local CurrentCamera = Workspace.CurrentCamera :: Camera

-- ── 涡旋参数（可按需调整） ────────────────────────────────────────────────
local VORTEX_MAX          = 35    -- 同屏最大飞线数
local VORTEX_INTERVAL     = 0.06  -- 生成间隔（秒）
local VORTEX_LIFETIME_MIN = 1.0   -- 单条飞线最短存活（秒）
local VORTEX_LIFETIME_MAX = 2.2   -- 单条飞线最长存活（秒）
local VORTEX_RADIUS_MIN   = 7     -- 生成最小半径（studs，避免遮挡镜头中心）
local VORTEX_RADIUS_MAX   = 32    -- 生成最大半径（studs）
local VORTEX_HEIGHT_RANGE = 14    -- 相对镜头 Y 的随机范围（±studs）

-- 线速度（切线方向，studs/秒）：内圈角速度更大，产生差速旋转效果
local VORTEX_TANGENTIAL   = 38    -- 越大旋转越快
-- 向内收拢速度（studs/秒）：让 streak 缓慢螺旋向中心
local VORTEX_INWARD       = 4.5
-- 向上漂移速度（studs/秒）
local VORTEX_UPWARD       = 7.0
-- 垂直扰动幅度（studs/秒）
local VORTEX_TURBULENCE   = 12.0

local VORTEX_TRAIL_LIFE   = 0.32  -- Trail 段存活时间（短→碎片感）
-- 飞线粗细由两 Attachment 间距（0.12 studs）× WidthScale 决定

-- 灰白到灰黑的渐变色
local COLORS: { Color3 } = {
	Color3.fromRGB(180, 180, 180), -- 浅灰白
	Color3.fromRGB(120, 120, 120), -- 中灰
	Color3.fromRGB(156, 154, 154),  -- 深灰
	Color3.fromHSV(0, 0.023148, 0.847059),  -- 接近黑
}

-- ── 风声 ─────────────────────────────────────────────────────────────────
local WIND_SOUND_ID = "rbxassetid://6042053626"

-- ── 状态 ─────────────────────────────────────────────────────────────────
local Tornado = {}
Tornado.enabled = false

local vortexContainer: Folder?  = nil
local vortexThread: thread?     = nil
local windSound: AudioPlayer?         = nil

-- ── 池化：单 RenderStepped 驱动所有活跃飞线 ──────────────────────────────

type VortexEntry = {
	part: Part,
	phase: number,
	expireAt: number,
}

local activeStreaks: { VortexEntry } = {}
local renderConn: RBXScriptConnection? = nil

-- ── 内部工具 ──────────────────────────────────────────────────────────────

local function makeVortexPart(parent: Instance, color: Color3): Part
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
	att0.Position   = Vector3.new(0, 0.06, 0)
	att0.Parent     = p

	local att1      = Instance.new("Attachment")
	att1.Position   = Vector3.new(0, -0.06, 0)
	att1.Parent     = p

	local t             = Instance.new("Trail")
	t.Attachment0       = att0
	t.Attachment1       = att1
	t.Lifetime          = VORTEX_TRAIL_LIFE
	t.MinLength         = 0
	t.FaceCamera        = true
	t.LightEmission     = 0
	t.LightInfluence    = 1
	t.Color             = ColorSequence.new(color)
	t.WidthScale        = NumberSequence.new({
		NumberSequenceKeypoint.new(0,    0),
		NumberSequenceKeypoint.new(0.18, 1),
		NumberSequenceKeypoint.new(0.82, 1),
		NumberSequenceKeypoint.new(1,    0),
	})
	t.Transparency      = NumberSequence.new({
		NumberSequenceKeypoint.new(0,    1),
		NumberSequenceKeypoint.new(0.18, 0.22),
		NumberSequenceKeypoint.new(0.82, 0.22),
		NumberSequenceKeypoint.new(1,    1),
	})
	t.Archivable        = false
	t.Parent            = p

	return p
end

local function spawnVortexStreak()
	if #activeStreaks >= VORTEX_MAX then return end
	if not vortexContainer then return end

	local color = COLORS[math.random(1, #COLORS)]
	local part  = makeVortexPart(vortexContainer, color)

	local radius = VORTEX_RADIUS_MIN + math.random() * (VORTEX_RADIUS_MAX - VORTEX_RADIUS_MIN)
	local angle  = math.random() * math.pi * 2
	local camPos = CurrentCamera.CFrame.Position
	part.Position = Vector3.new(
		camPos.X + radius * math.cos(angle),
		camPos.Y + (math.random() * 2 - 1) * VORTEX_HEIGHT_RANGE,
		camPos.Z + radius * math.sin(angle)
	)

	local phase    = math.random() * math.pi * 2
	local lifetime = VORTEX_LIFETIME_MIN + math.random() * (VORTEX_LIFETIME_MAX - VORTEX_LIFETIME_MIN)

	table.insert(activeStreaks, {
		part = part,
		phase = phase,
		expireAt = os.clock() + lifetime,
	})
end

local function connectRenderLoop()
	if renderConn then return end

	renderConn = RunService.RenderStepped:Connect(function(dt: number)
		local now = os.clock()
		local cp  = CurrentCamera.CFrame.Position
		local i = 1
		while i <= #activeStreaks do
			local entry = activeStreaks[i]

			if now >= entry.expireAt then
				-- Trail 自然消散后销毁 Part
				task.delay(VORTEX_TRAIL_LIFE + 0.05, function()
					entry.part:Destroy()
				end)
				local n = #activeStreaks
				activeStreaks[i] = activeStreaks[n]
				activeStreaks[n] = nil
				continue
			end

			local part = entry.part
			local dx  = part.Position.X - cp.X
			local dz  = part.Position.Z - cp.Z
			local r   = math.sqrt(dx * dx + dz * dz)

			local vTan: Vector3
			local vIn:  Vector3
			if r > 0.5 then
				vTan = Vector3.new(-dz / r, 0,  dx / r) * (VORTEX_TANGENTIAL * dt)
				vIn  = Vector3.new(-dx / r, 0, -dz / r) * (VORTEX_INWARD * dt)
			else
				vTan = Vector3.zero
				vIn  = Vector3.zero
			end

			local turbY = VORTEX_TURBULENCE * math.sin(now * 6.5 + entry.phase) * dt

			part.Position += vTan + vIn
				+ Vector3.new(0, VORTEX_UPWARD * dt + turbY, 0)

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

local function startVortexLoop()
	vortexThread = task.spawn(function()
		while Tornado.enabled do
			spawnVortexStreak()
			task.wait(VORTEX_INTERVAL)
		end
	end)
end

local function _buildWindSound()
	local ambientBus = SoundService:FindFirstChild("Audio")
	local ambientFader = ambientBus and ambientBus:FindFirstChild("Busses")
		and ambientBus.Busses:FindFirstChild("Ambient")
		and ambientBus.Busses.Ambient:FindFirstChild("AudioFader")

	local s      = Instance.new("AudioPlayer")
	s.Name       = "__TornadoWind"
	s.Asset      = WIND_SOUND_ID
	s.Volume     = 0
	s.Looping    = true
	s.Parent     = SoundService

	if ambientFader then
		local wire = Instance.new("Wire")
		wire.Name = "Wire"
		wire.SourceInstance = s
		wire.SourceName = "Output"
		wire.TargetInstance = ambientFader
		wire.TargetName = "Input"
		wire.Parent = s
	end

	windSound = s
end

--buildWindSound()

-- ── 公共接口 ──────────────────────────────────────────────────────────────

function Tornado:Enable(tweenInfo: TweenInfo?)
	if Tornado.enabled then return end
	Tornado.enabled = true

	local info = tweenInfo or TweenInfo.new(3, Enum.EasingStyle.Linear)

	local folder      = Instance.new("Folder")
	folder.Name       = "__TornadoVortex"
	folder.Archivable = false
	folder.Parent     = Workspace
	vortexContainer   = folder

	connectRenderLoop()
	startVortexLoop()

	if windSound then
		windSound:Play()
		TweenService:Create(windSound, info, { Volume = 0.85 }):Play()
	end
end

function Tornado:Disable(tweenInfo: TweenInfo?)
	if not Tornado.enabled then return end
	Tornado.enabled = false

	local info = tweenInfo or TweenInfo.new(3, Enum.EasingStyle.Linear)

	if vortexThread then
		task.cancel(vortexThread)
		vortexThread = nil
	end

	disconnectRenderLoop()
	clearAllStreaks()

	if vortexContainer then
		vortexContainer:Destroy()
		vortexContainer = nil
	end

	if windSound then
		local tween = TweenService:Create(windSound, info, { Volume = 0 })
		tween.Completed:Once(function(state: Enum.PlaybackState)
			if state == Enum.PlaybackState.Completed and windSound then
				windSound:Stop()
			end
		end)
		tween:Play()
	end
end

function Tornado:SetIntensityRatio(_val: number, _tweenInfo: TweenInfo?) end

return Tornado
