--!strict
-- Thunder.luau
-- 雷暴特效处理器：
--   视觉 —— LightningEffect 生成从高空到地面的电弧（真实电流感）
--   光效 —— 蓝白 ColorCorrection 同步闪烁
--   音效 —— LightningEffect 内置，此处不再单独管理

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting          = game:GetService("Lighting")
local Workspace         = game:GetService("Workspace")

local LightningEffect = require(ReplicatedStorage.ReplicatedCode.Framework.Effects.Lightning.LightningEffect)

local CurrentCamera = Workspace.CurrentCamera :: Camera

-- ── 闪电参数 ──────────────────────────────────────────────────────────────
local BRIGHTNESS_SPIKE  = 7.5   -- 闪电时亮度峰值
local FLASH_DURATION    = 0.07  -- 单次闪光持续（秒）
local DOUBLE_CHANCE     = 0.4   -- 双闪概率
local DOUBLE_DELAY      = 0.13  -- 双闪间隔（秒）
local INTERVAL_MIN      = 15    -- 两次闪电最小间隔（秒）
local INTERVAL_MAX      = 40.0  -- 两次闪电最大间隔（秒）

local BOLT_GROUND_Y     = 2     -- 电弧落点高度（接近地面）

-- ── 状态 ─────────────────────────────────────────────────────────────────
local Thunder = {}
Thunder.enabled = false

local loopThread: thread?                    = nil
local colorCorrection: ColorCorrectionEffect? = nil

-- ── 内部工具 ──────────────────────────────────────────────────────────────

local function doSingleFlash(spike: number)
	if colorCorrection then
		colorCorrection.TintColor = Color3.fromRGB(210, 220, 255)
		colorCorrection.Brightness = 0.5
	end
	task.delay(FLASH_DURATION, function()
		if not Thunder.enabled then return end
		if colorCorrection then
			colorCorrection.TintColor = Color3.new(1, 1, 1)
			colorCorrection.Brightness = 0
		end
	end)
end

local function doStrike()
	if not Thunder.enabled then return end

	local camCFrame = CurrentCamera.CFrame

	local look = camCFrame.LookVector
	look = Vector3.new(look.X, 0, look.Z)
	if look.Magnitude > 0.001 then
		look = look.Unit
	else
		look = Vector3.new(0, 0, -1)
	end

	local forwardDist = math.random(150, 300)
	local right = camCFrame.RightVector
	right = Vector3.new(right.X, 0, right.Z)
	if right.Magnitude > 0.001 then
		right = right.Unit
	else
		right = Vector3.new(1, 0, 0)
	end
	local rightDist = math.random(-150, 150)

	local targetPos = camCFrame.Position + look * forwardDist + right * rightDist

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	local raycast = Workspace:Raycast(targetPos + Vector3.new(0, 100, 0), Vector3.new(0, -200, 0), raycastParams)
	if raycast then
		local isWater = false
		if raycast.Instance then
			isWater = raycast.Instance.CollisionGroup == "Water" or raycast.Material == Enum.Material.Water
		end

		task.spawn(function()
			LightningEffect(raycast.Position, isWater)
		end)
	else
		task.spawn(function()
			LightningEffect(Vector3.new(targetPos.X, BOLT_GROUND_Y, targetPos.Z), false)
		end)
	end

	doSingleFlash(BRIGHTNESS_SPIKE)

	if math.random() < DOUBLE_CHANCE then
		task.delay(DOUBLE_DELAY, function()
			if not Thunder.enabled then return end
			doSingleFlash(BRIGHTNESS_SPIKE * 0.55)
		end)
	end
end

local function startLoop()
	loopThread = task.spawn(function()
		task.wait(2)
		while Thunder.enabled do
			doStrike()
			task.wait(INTERVAL_MIN + math.random() * (INTERVAL_MAX - INTERVAL_MIN))
		end
	end)
end

-- ── 公共接口 ──────────────────────────────────────────────────────────────

function Thunder:Enable(_tweenInfo: TweenInfo?)
	if Thunder.enabled then return end
	Thunder.enabled = true

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name       = "__ThunderCC"
	cc.TintColor  = Color3.new(1, 1, 1)
	cc.Archivable = false
	cc.Parent     = Lighting
	colorCorrection = cc

	startLoop()
end

function Thunder:Disable(_tweenInfo: TweenInfo?)
	if not Thunder.enabled then return end
	Thunder.enabled = false

	if loopThread then
		task.cancel(loopThread)
		loopThread = nil
	end

	if colorCorrection then
		colorCorrection:Destroy()
		colorCorrection = nil
	end
end

function Thunder:SetIntensityRatio(_val: number, _tweenInfo: TweenInfo?) end

return Thunder
