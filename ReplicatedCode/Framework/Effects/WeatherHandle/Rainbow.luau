--!strict
-- Rainbow.luau
-- 彩虹特效：克隆 CodeAssets.Effects.RainbowModel，运行时只负责缩放、跟随与显隐。

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local getCodeAsset = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Instance.GetCodeAsset)

-- ── 彩虹几何 ──────────────────────────────────────────────────────────────
-- 彩虹始终出现在玩家 FOLLOW_DIR 方向、水平距离 RAINBOW_DISTANCE 处，
-- 高度固定为世界 Y = RAINBOW_HEIGHT，左右各延伸 HALF_SPAN。
local RAINBOW_DISTANCE = 450 -- 彩虹距相机水平距离（studs），改大增加远景感
local RAINBOW_OFFSET_X = 140 -- 侧向偏移（正数向右，负数向左），避免完全居中
local RAINBOW_HEIGHT = 30 -- 彩虹锚点世界 Y 高度，配合 RainbowModel 整体略微上移
local HALF_SPAN = 250 -- 彩虹左右半跨，跨度更大
-- FOLLOW_DIR：彩虹出现的水平方向（XZ 单位向量），可调整为地图任意朝向
local FOLLOW_DIR = Vector3.new(0, 0, -1)

local RAINBOW_MODEL_NAME = "RainbowModel"

local FOLLOW_ALPHA = 0.12 -- 每帧插值系数（0~1，越小跟随越滞后/平滑）

local WARM_TINT = Color3.fromRGB(255, 248, 235) -- 雨后清晨暖色调
local NEUTRAL_TINT = Color3.new(1, 1, 1)

-- ── 状态 ─────────────────────────────────────────────────────────────────
local Rainbow = {}
Rainbow.enabled = false

local colorCorrection: ColorCorrectionEffect? = nil
local rainbowModel: Model? = nil
local anchorCenterOffset = Vector3.zero
local followConn: RBXScriptConnection? = nil

-- ── 内部工具 ──────────────────────────────────────────────────────────────

-- 根据玩家/相机位置计算彩虹中心的世界 XZ 基准点
local function getViewerPosition(): Vector3
    -- 优先使用相机位置，这样玩家拉远镜头时彩虹大小在屏幕上保持不变，增加沉浸感
    local cam = Workspace.CurrentCamera
    if cam then
        return cam.CFrame.Position
    end
    local player = Players.LocalPlayer
    local char = player and player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
    if root then
        return root.Position
    end
    return Vector3.zero
end

local function getFollowBase(): Vector3
    local p = getViewerPosition()
    return Vector3.new(p.X, 0, p.Z)
end

-- 计算目标锚点位置（不含插值）
local function computeAnchorPositions(): (Vector3, Vector3)
    local base = getFollowBase()
    local right = Vector3.new(-FOLLOW_DIR.Z, 0, FOLLOW_DIR.X)
    local center = base + FOLLOW_DIR * RAINBOW_DISTANCE + right * RAINBOW_OFFSET_X
    local lPos = Vector3.new(center.X, RAINBOW_HEIGHT, center.Z) - right * HALF_SPAN
    local rPos = Vector3.new(center.X, RAINBOW_HEIGHT, center.Z) + right * HALF_SPAN
    return lPos, rPos
end

local function getRequiredAttachment(model: Model, name: string): Attachment
    local attachment = model:FindFirstChild(name, true)
    if not attachment or not attachment:IsA("Attachment") then
        error(`RainbowModel missing Attachment {name}`)
    end
    return attachment
end

local function applyRainbowPose(lPos: Vector3, rPos: Vector3)
    if not rainbowModel then
        return
    end

    local center = (lPos + rPos) * 0.5
    local viewerPos = getViewerPosition()
    local lookDir = Vector3.new(viewerPos.X - center.X, 0, viewerPos.Z - center.Z)
    if lookDir.Magnitude < 0.001 then
        lookDir = -FOLLOW_DIR
    end
    lookDir = lookDir.Unit

    -- Root 朝向玩家，同时让 A0/A1 中点落在旧逻辑计算出的彩虹中心。
    local rotation = CFrame.lookAt(Vector3.zero, lookDir)
    local pivotPos = center - rotation:VectorToWorldSpace(anchorCenterOffset)
    rainbowModel:PivotTo(CFrame.lookAt(pivotPos, pivotPos + lookDir))
end

local function buildRainbow()
    local templateInstance = getCodeAsset("Effects", RAINBOW_MODEL_NAME) :: Instance
    assert(templateInstance:IsA("Model"), "RainbowModel prefab must be a Model")
    local template = templateInstance :: Model

    local model = template:Clone()
    model.Name = "__RainbowModel"
    model.Archivable = false

    for _, descendant in ipairs(model:GetDescendants()) do
        descendant.Archivable = false
        if descendant:IsA("BasePart") then
            descendant.Anchored = true
            descendant.CanCollide = false
            descendant.CanQuery = false
            descendant.CanTouch = false
            descendant.CastShadow = false
        end
    end

    local a0 = getRequiredAttachment(model, "A0")
    local a1 = getRequiredAttachment(model, "A1")
    local sourceSpan = (a0.WorldPosition - a1.WorldPosition).Magnitude
    assert(sourceSpan > 0, "RainbowModel A0/A1 span must be greater than 0")
    model:ScaleTo(1.5)
    anchorCenterOffset = model:GetPivot():PointToObjectSpace((a0.WorldPosition + a1.WorldPosition) * 0.5)

    rainbowModel = model
end

local function setupColorCorrection()
    local cc = Instance.new("ColorCorrectionEffect")
    cc.Name = "__RainbowCC"
    cc.TintColor = NEUTRAL_TINT
    cc.Archivable = false
    cc.Parent = Lighting
    colorCorrection = cc
end

-- ── 初始化（模块 require 时执行一次） ────────────────────────────────────
buildRainbow()
setupColorCorrection()

-- 跟随循环：Enable 时启动，Disable 时停止，节省其他天气效果运行时的开销
local lCurrent = Vector3.zero
local rCurrent = Vector3.zero

local function startFollow()
    if followConn then
        return
    end
    -- 立即定位，避免首帧从旧位置插值
    lCurrent, rCurrent = computeAnchorPositions()
    applyRainbowPose(lCurrent, rCurrent)

    followConn = RunService.Heartbeat:Connect(function()
        if not rainbowModel then
            return
        end
        local lTarget, rTarget = computeAnchorPositions()
        lCurrent = lCurrent:Lerp(lTarget, FOLLOW_ALPHA)
        rCurrent = rCurrent:Lerp(rTarget, FOLLOW_ALPHA)
        applyRainbowPose(lCurrent, rCurrent)
    end)
end

local function stopFollow()
    if followConn then
        followConn:Disconnect()
        followConn = nil
    end
end

-- ── 公共接口 ──────────────────────────────────────────────────────────────

function Rainbow:Enable(tweenInfo: TweenInfo?)
    if Rainbow.enabled then
        return
    end
    Rainbow.enabled = true
    if rainbowModel then
        rainbowModel.Parent = Workspace
    end
    startFollow()

    local info = tweenInfo or TweenInfo.new(3, Enum.EasingStyle.Linear)
    if colorCorrection then
        TweenService:Create(colorCorrection, info, { TintColor = WARM_TINT }):Play()
    end
end

function Rainbow:Disable(tweenInfo: TweenInfo?)
    if not Rainbow.enabled then
        return
    end
    Rainbow.enabled = false

    local info = tweenInfo or TweenInfo.new(3, Enum.EasingStyle.Linear)
    stopFollow()
    if rainbowModel then
        rainbowModel.Parent = nil
    end
    if colorCorrection then
        TweenService:Create(colorCorrection, info, { TintColor = NEUTRAL_TINT }):Play()
    end
end

function Rainbow:SetIntensityRatio(_val: number, _tweenInfo: TweenInfo?) end

return Rainbow
