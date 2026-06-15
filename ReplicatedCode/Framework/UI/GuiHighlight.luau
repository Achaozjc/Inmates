--!strict
--[[
	GuiHighlight — 2D GUI 按钮高亮引导模块

	原理：
	  将 PlayerGui 中的 HightLighFrameGui.HighlightRoot.Mask 对齐到目标控件，
	  利用 UIStroke Thickness=999 把四周区域遮暗，中央镂空区域自然凸显目标按钮；
	  同时播放呼吸 Tween 吸引玩家注意。
	  不改变 HightLighFrameGui 的 ScreenInsets；目标与高亮层 inset 可不同，依赖 Absolute* 的统一坐标换算。

	用法：
	  GuiHighlight.show(button)          -- 高亮指定控件
	  GuiHighlight.show(button, 12)      -- 自定义额外 padding（默认 8）
	  GuiHighlight.hide()                -- 关闭高亮
]]

local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")
local Players      = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local getCodeAsset = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Instance.GetCodeAsset)
local UILayerHandler = require(ReplicatedStorage.ReplicatedCode.Framework.UI.UILayerHandler)

-- 呼吸动画：Mask Size 轻微缩放（每侧扩展 BREATH_PADDING 像素后缩回）
local BREATH_PADDING = 5        -- 呼吸时每侧额外扩展的像素
local FIXED_TRANSPARENCY = 0.30 -- 描边固定透明度，不随动画变化
local BREATH_TWEEN = TweenInfo.new(0.85, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

local prefabFolder: Folder = getCodeAsset("UI", "GuiHighlight")
local _gui    = prefabFolder:WaitForChild("HightLighFrameGui") :: ScreenGui
-- 全屏透明根节点在 ReplicatedStorage.Instances.CodeAssets.UI.GuiHighlight 内维护，便于父级用 AbsolutePosition 换算
local _mask   = _gui:WaitForChild("HighlightRoot"):WaitForChild("Mask") :: Frame
local _stroke = _mask:FindFirstChildOfClass("UIStroke") :: UIStroke

local player = Players.LocalPlayer
-- 保证遮罩盖在菜单与引导 HUD 之上；具体数值高于默认 ScreenGui 即可
_gui.DisplayOrder = 101
_gui.Parent  = player.PlayerGui
_gui.Enabled = false -- 默认隐藏

local DEFAULT_PADDING = 8 -- 高亮框比目标控件多出的像素（每侧）

-- ── 模块 ──────────────────────────────────────────────────────────────────────

local GuiHighlight = {}

local _breatheTween: Tween? = nil
local _absPosConn: RBXScriptConnection? = nil
local _absSizeConn: RBXScriptConnection? = nil

local function _disconnectFollow()
	if _absPosConn then
		_absPosConn:Disconnect()
		_absPosConn = nil
	end
	if _absSizeConn then
		_absSizeConn:Disconnect()
		_absSizeConn = nil
	end
end

local function _originAbsForMaskParent(mask: Frame): Vector2
	local parentInst: Instance? = mask.Parent
	if parentInst and parentInst:IsA("GuiObject") then
		return (parentInst :: GuiObject).AbsolutePosition
	end
	if parentInst and parentInst:IsA("ScreenGui") then
		-- 根容器原点：Studio 中可见 ScreenGui.AbsolutePosition（刘海/横屏 + None 时常为负）
		local anySg = parentInst :: any
		local ap = anySg.AbsolutePosition
		if typeof(ap) == "Vector2" then
			return ap
		end
		-- 回退：按当前 ScreenGui 的 ScreenInsets 取内容区左上角
		local sg = parentInst :: ScreenGui
		return GuiService:GetInsetArea(sg.ScreenInsets).Min
	end
	return Vector2.zero
end

-- 将 Mask 对齐到目标控件（基于绝对坐标）
local function _alignMask(mask: Frame, target: GuiObject, padding: number)
	local absPos = target.AbsolutePosition
	local absSize = target.AbsoluteSize
	-- 不修改 HightLighFrameGui 的 ScreenInsets（全屏遮罩需保持预制默认，如 None）。
	-- 引擎文档：ScreenGui 下的 AbsolutePosition / AbsoluteSize 均为 CoreUISafe 视口坐标，
	-- 与目标所在 ScreenGui 的 ScreenInsets（DeviceSafe / None 等）无关；目标与高亮父级同坐标系，直接做向量差即可。
	local centerAbs = absPos + absSize * 0.5
	local centerLocal = centerAbs - _originAbsForMaskParent(mask)

	-- 以中心定位，防止 AnchorPoint 不同带来的偏移计算困难
	mask.AnchorPoint = Vector2.new(0.5, 0.5)
	mask.Position = UDim2.fromOffset(centerLocal.X, centerLocal.Y)
	mask.Size = UDim2.fromOffset(
		absSize.X + padding * 2,
		absSize.Y + padding * 2
	)
end

local function _stopBreathing()
	if _breatheTween then
		_breatheTween:Cancel()
		_breatheTween = nil
	end
end

-- ── 公开接口 ──────────────────────────────────────────────────────────────────

--[[
	高亮指定 GuiObject。
	@param target  要凸显的控件（TextButton、ImageButton、Frame 等均可）
	@param padding 额外描边间距，默认 8 像素
]]
function GuiHighlight.show(target: GuiObject, padding: number?)
	_stopBreathing()
	_disconnectFollow()
	-- 高亮出现时同步手柄选中框到当前目标，便于手柄玩家直接确认点击
	if target.Selectable then
		UILayerHandler.setGamepadCursorTarget(target, true, nil, true)
	end

	local pad = padding or DEFAULT_PADDING
	local function realign()
		if not target.Parent or not _gui.Enabled then
			return
		end
		_alignMask(_mask, target, pad)
	end

	local function restartBreathe()
		local absSize = target.AbsoluteSize
		local baseW = absSize.X + pad * 2
		local baseH = absSize.Y + pad * 2
		_stopBreathing()
		_mask.Size = UDim2.fromOffset(baseW, baseH)
		local breatheTween = TweenService:Create(_mask, BREATH_TWEEN, {
			Size = UDim2.fromOffset(baseW + BREATH_PADDING * 2, baseH + BREATH_PADDING * 2),
		})
		_breatheTween = breatheTween
		breatheTween:Play()
	end

	realign()

	-- 固定描边透明度
	_stroke.Transparency = FIXED_TRANSPARENCY
	_gui.Enabled = true

	restartBreathe()

	-- MenuBoard 等刚展开时布局未结算；延后一帧再对齐并重启呼吸，避免镂空偏移
	task.defer(function()
		RunService.Heartbeat:Wait()
		if not _gui.Enabled or not target.Parent then
			return
		end
		realign()
		restartBreathe()
		if target.Selectable then
			UILayerHandler.setGamepadCursorTarget(target, true, nil, true)
		end
	end)

	local function onTargetGeometryChanged()
		realign()
		restartBreathe()
	end

	_absPosConn = target:GetPropertyChangedSignal("AbsolutePosition"):Connect(onTargetGeometryChanged)
	_absSizeConn = target:GetPropertyChangedSignal("AbsoluteSize"):Connect(onTargetGeometryChanged)
end

--[[
	关闭高亮，停止呼吸动画。
]]
function GuiHighlight.hide()
	_stopBreathing()
	_disconnectFollow()
	-- 高亮关闭后清空手柄目标，避免残留到已无效控件
	UILayerHandler.setGamepadCursorTarget(nil)
	_gui.Enabled = false
end

return GuiHighlight
