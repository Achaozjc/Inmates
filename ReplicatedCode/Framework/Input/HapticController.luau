--!strict
--[[
	手柄震动统一入口
	- pulse(small, large, duration, lt?, rt?) : 一次性脉冲(命中/释放/爆发);lt/rt 为可选扳机强度
	- bind(id, fn)                            : 持续震动源,fn 每帧返回 (small, large [, lt, rt])
	- unbind(id)                              : 移除持续源
	- setEnabled(enabled)                     : 全局开关(接入玩家设置)
	震动强度聚合规则:对每个电机各自取所有源的最大值,避免互相覆盖
	扳机电机(LeftTrigger/RightTrigger)仅 Xbox One 起的手柄支持,不支持时自动忽略
]]

local HapticService = game:GetService("HapticService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- 返回 (small, large, leftTrigger?, rightTrigger?);后两个可省略(nil 视为 0)
export type StrengthFn = () -> (number, number, number?, number?)

type Source = {
	fn: StrengthFn?,
	small: number,
	large: number,
	lt: number,
	rt: number,
	expireAt: number?,
}

local HapticController = {
	_sources = {} :: { [string]: Source },
	_heartbeat = nil :: RBXScriptConnection?,
	_enabled = true,
	_lastSmall = 0,
	_lastLarge = 0,
	_lastLT = 0,
	_lastRT = 0,
	_pulseSeq = 0,
}

local function getGamepad(): Enum.UserInputType?
	local last = UserInputService:GetLastInputType()
	if string.find(last.Name, "Gamepad") then
		return last
	end
	local connected = UserInputService:GetConnectedGamepads()
	if #connected > 0 then
		return connected[1]
	end
	return nil
end

local function applyMotors(small: number, large: number, lt: number, rt: number)
	local gp = getGamepad()
	if not gp then
		-- 手柄未连,无需下发
		HapticController._lastSmall = 0
		HapticController._lastLarge = 0
		HapticController._lastLT = 0
		HapticController._lastRT = 0
		return
	end
	small = math.clamp(small, 0, 1)
	large = math.clamp(large, 0, 1)
	lt = math.clamp(lt, 0, 1)
	rt = math.clamp(rt, 0, 1)
	if
		HapticController._lastSmall == small
		and HapticController._lastLarge == large
		and HapticController._lastLT == lt
		and HapticController._lastRT == rt
	then
		return
	end
	-- Small/Large 主电机：不经 IsMotorSupported 守门，直接调用。
	-- PS4/PS5/Switch 等机型该 API 存在误报 false 的已知问题；
	-- SetMotor 在硬件不支持时由 Roblox 内部静默忽略，直接调用兼容性更好。
	HapticService:SetMotor(gp, Enum.VibrationMotor.Small, small)
	HapticService:SetMotor(gp, Enum.VibrationMotor.Large, large)
	-- 扳机电机(LeftTrigger/RightTrigger)仅 Xbox One Impulse Triggers / DualSense 支持,
	-- 保留 IsMotorSupported 守门避免在不支持的机型上产生不必要的 API 调用
	if HapticService:IsMotorSupported(gp, Enum.VibrationMotor.LeftTrigger) then
		HapticService:SetMotor(gp, Enum.VibrationMotor.LeftTrigger, lt)
	end
	if HapticService:IsMotorSupported(gp, Enum.VibrationMotor.RightTrigger) then
		HapticService:SetMotor(gp, Enum.VibrationMotor.RightTrigger, rt)
	end
	HapticController._lastSmall = small
	HapticController._lastLarge = large
	HapticController._lastLT = lt
	HapticController._lastRT = rt
end

local function stopHeartbeatIfIdle()
	if not HapticController._heartbeat then
		return
	end
	if next(HapticController._sources) == nil then
		HapticController._heartbeat:Disconnect()
		HapticController._heartbeat = nil
		applyMotors(0, 0, 0, 0)
	end
end

local function ensureHeartbeat()
	if HapticController._heartbeat then
		return
	end
	HapticController._heartbeat = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local sumSmall, sumLarge, sumLT, sumRT = 0, 0, 0, 0
		local expiredKeys: { string } = {}

		for id, source in HapticController._sources do
			if source.expireAt and now >= source.expireAt then
				table.insert(expiredKeys, id)
				continue
			end
			local s, l, lt, rt
			if source.fn then
				s, l, lt, rt = source.fn()
				lt = lt or 0
				rt = rt or 0
			else
				s, l, lt, rt = source.small, source.large, source.lt, source.rt
			end
			if s > sumSmall then
				sumSmall = s
			end
			if l > sumLarge then
				sumLarge = l
			end
			if lt > sumLT then
				sumLT = lt
			end
			if rt > sumRT then
				sumRT = rt
			end
		end

		for _, id in expiredKeys do
			HapticController._sources[id] = nil
		end

		if HapticController._enabled then
			applyMotors(sumSmall, sumLarge, sumLT, sumRT)
		else
			applyMotors(0, 0, 0, 0)
		end

		stopHeartbeatIfIdle()
	end)
end

function HapticController.pulse(small: number, large: number, duration: number, lt: number?, rt: number?)
	HapticController._pulseSeq += 1
	local id = "_pulse_" .. tostring(HapticController._pulseSeq)
	HapticController._sources[id] = {
		small = small,
		large = large,
		lt = lt or 0,
		rt = rt or 0,
		expireAt = os.clock() + duration,
	}
	ensureHeartbeat()
end

-- 扳机专属脉冲:只震扳机电机,留出 Small/Large 给并发的其它反馈(如按键脆响叠在拉杆手感上)
function HapticController.pulseTrigger(lt: number, rt: number, duration: number)
	HapticController._pulseSeq += 1
	local id = "_pulseT_" .. tostring(HapticController._pulseSeq)
	HapticController._sources[id] = {
		small = 0,
		large = 0,
		lt = lt,
		rt = rt,
		expireAt = os.clock() + duration,
	}
	ensureHeartbeat()
end

function HapticController.bind(id: string, fn: StrengthFn)
	HapticController._sources[id] = { fn = fn, small = 0, large = 0, lt = 0, rt = 0 }
	ensureHeartbeat()
end

function HapticController.unbind(id: string)
	HapticController._sources[id] = nil
	if HapticController._heartbeat and next(HapticController._sources) == nil then
		-- 立刻清零,避免下一个 Heartbeat 前仍在抖
		applyMotors(0, 0, 0, 0)
	end
end

function HapticController.stopAll()
	HapticController._sources = {}
	applyMotors(0, 0, 0, 0)
	if HapticController._heartbeat then
		HapticController._heartbeat:Disconnect()
		HapticController._heartbeat = nil
	end
end

function HapticController.setEnabled(enabled: boolean)
	HapticController._enabled = enabled
	if not enabled then
		applyMotors(0, 0, 0, 0)
	end
end

function HapticController.isEnabled(): boolean
	return HapticController._enabled
end

-- 手柄断连时强制清零,防止电机卡在某强度
UserInputService.GamepadDisconnected:Connect(function()
	HapticController._lastSmall = 0
	HapticController._lastLarge = 0
	HapticController._lastLT = 0
	HapticController._lastRT = 0
end)

-- ============================================================
-- 业务预设:让调用方不用记魔数,也方便统一调校
-- ============================================================

function HapticController.tick()
	-- 短脆按键感(菜单/切换/滚轮格位)
	HapticController.pulse(0.6, 0, 0.04)
end

function HapticController.success()
	-- 确认感:高频短 + 低频尾
	HapticController.pulse(0.5, 0.3, 0.12)
end

function HapticController.fail()
	-- 错误:低频双点
	HapticController.pulse(0, 0.7, 0.08)
	task.delay(0.13, function()
		HapticController.pulse(0, 0.7, 0.08)
	end)
end

function HapticController.warn()
	-- 警告:中频长震,提醒注意
	HapticController.pulse(0.2, 0.6, 0.3)
end

function HapticController.heavy(duration: number?)
	-- 重击(上钩 / 大奖励 / 爆发)
	HapticController.pulse(0.5, 1, duration or 0.25)
end

-- 稀有度奖励震动分级(稀有度 4-7 / 解锁 / 大笔奖励)
function HapticController.reward(rarity: number)
	if rarity <= 3 then
		HapticController.success()
		return
	end
	if rarity == 4 then
		-- Epic:双拍,第二拍轻推两扳机
		HapticController.pulse(0.4, 0.7, 0.12)
		task.delay(0.16, function()
			HapticController.pulse(0.5, 0.9, 0.2, 0.5, 0.5)
		end)
	elseif rarity == 5 then
		-- Legendary:三拍递进,扳机同步阶梯递增
		for i = 1, 3 do
			task.delay((i - 1) * 0.15, function()
				local s = 0.3 + i * 0.2
				local l = 0.4 + i * 0.2
				local t = i * 0.25
				HapticController.pulse(s, l, 0.12 + i * 0.04, t, t)
			end)
		end
	elseif rarity == 6 then
		-- Mythical:四拍 + 长尾,扳机全程高位
		for i = 1, 4 do
			task.delay((i - 1) * 0.12, function()
				HapticController.pulse(0.4 + i * 0.15, 0.5 + i * 0.12, 0.1, 0.6, 0.6)
			end)
		end
		task.delay(0.65, function()
			HapticController.pulse(0.5, 1, 0.4, 1, 1)
		end)
	else
		-- Secret / rarity 7+:连续颤震 + 终极双扳机轰炸
		for i = 1, 6 do
			task.delay((i - 1) * 0.1, function()
				HapticController.pulse(0.6, 0.7, 0.08, 0.7, 0.7)
			end)
		end
		task.delay(0.75, function()
			HapticController.pulse(0.9, 1, 0.5, 1, 1)
		end)
	end
end

return HapticController
