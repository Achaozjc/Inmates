--!strict

--[[
	群组奖励 Billboard 控制器（纯客户端显示）。

	刷新本地玩家基地 TouchedButtons/Group/Billboard/Main 下两个标签：
		- CashAmount：当前可领取额（= GroupRewardConfig.getReward(ownedAxeCount)），随斧头数变化刷新。
		- CountDown ：领取冷却倒计时 MM:SS（默认 Visible=false）；冷却中显示、可领取时隐藏。
		- Group_Model 霓虹：可领取=绿，冷却中=灰。

	倒计时基于玩家属性 AttributeEnum.GroupRewardReadyAt（服务端写入的下次可领取 Unix 时间，
	0=可立即领取）：据其算出剩余秒数后用 CountDown 工具逐秒递减。属性变化（领取/重连）即
	重启倒计时。发放/领取逻辑见服务端 GroupRewardService。
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Framework = ReplicatedStorage.ReplicatedCode.Framework
local GameLogic = ReplicatedStorage.ReplicatedCode.GameLogic

local PlayerDataClient = require(Framework.DataStore.PlayerDataClient)
local ShowUnitNum = require(Framework.UI.ShowUnitNum)
local startCountdown = require(Framework.Utility.Time.CountDown)
local Network = require(Framework.Core.Network)
local SocialManager = require(GameLogic.Managers.SocialManager)
local GroupRewardConfig = require(GameLogic.Shared.Configs.GroupRewardConfig)
local AttributeEnum = require(GameLogic.Shared.Enums.AttributeEnum)
local PlayerDataKey = require(GameLogic.SharedConstants.Keys.PlayerDataKey)
local RemoteEventKey = require(GameLogic.SharedConstants.Keys.RemoteEventKey)

local localPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() :: Player

-- 与 TouchButtonNeonController 一致：可触发=绿，不可触发=灰
local COLOR_ENABLED = Color3.fromRGB(98, 163, 98)
local COLOR_DISABLED = Color3.fromRGB(86, 86, 86)

local GroupRewardBillboardController = {
	Name = "GroupRewardBillboardController",
	_started = false,
	_prompting = false,
	_cashLabel = nil :: TextLabel?,
	_countLabel = nil :: TextLabel?,
	_neon = nil :: BasePart?,
	_countToken = 0, -- 倒计时代号：自增使旧倒计时通过 stopFlag 自行结束
}

-- 服务端通知未加入群组：弹出加群提示（弹窗期间忽略重复请求，避免触碰去抖内多次弹出）
function GroupRewardBillboardController:promptJoin()
	if self._prompting then
		return
	end
	self._prompting = true
	task.spawn(function()
		SocialManager.joinCommunity()
		self._prompting = false
	end)
end

local function findBaseByOwner(userId: number): Folder?
	local world = Workspace:FindFirstChild("World")
	if not world then
		return nil
	end
	for _, child in world:GetChildren() do
		if child:IsA("Folder") and string.match(child.Name, "^Base_%d+$") then
			if child:GetAttribute(AttributeEnum.OwnerId) == userId then
				return child
			end
		end
	end
	return nil
end

local function waitForMyBase(): Folder
	local base = findBaseByOwner(localPlayer.UserId)
	while not base do
		task.wait(0.1)
		base = findBaseByOwner(localPlayer.UserId)
	end
	return base
end

-- 带超时的 WaitForChild 链式查找：刚进服时 TouchedButtons 子树可能尚未复制完成
local function waitForDescendant(root: Instance, names: { string }, timeout: number): Instance?
	local current: Instance? = root
	for _, name in names do
		if not current then
			return nil
		end
		current = current:WaitForChild(name, timeout)
	end
	return current
end

local GROUP_BILLBOARD_MAIN_PATH = { "Touch_Group", "Group", "Billboard", "Main" }

-- 读取本地玩家当前拥有斧头数
local function getOwnedAxeCount(): number
	local axeTycoon = PlayerDataClient.get(PlayerDataKey.AxeTycoon)
	return if type(axeTycoon) == "table" then (tonumber(axeTycoon.ownedAxeCount) or 0) else 0
end

-- 刷新可领取金额
function GroupRewardBillboardController:refreshCash()
	local label = self._cashLabel
	if label then
		label.Text = "$" .. ShowUnitNum(GroupRewardConfig.getReward(getOwnedAxeCount()))
	end
end

-- 冷却中：显示 MM:SS + 灰霓虹
function GroupRewardBillboardController:_showCooldown(timeLeft: number)
	local label = self._countLabel
	if label then
		label.Visible = true
		label.Text = string.format("Next in : %02d:%02d", math.floor(timeLeft / 60), timeLeft % 60)
	end
	local neon = self._neon
	if neon and neon.Parent then
		neon.Color = COLOR_DISABLED
	end
end

-- 可领取：隐藏倒计时 + 绿霓虹（CountDown 默认 Visible=false）
function GroupRewardBillboardController:_showReady()
	local label = self._countLabel
	if label then
		label.Visible = false
	end
	local neon = self._neon
	if neon and neon.Parent then
		neon.Color = COLOR_ENABLED
	end
end

-- 据下次可领取时间重启倒计时：冷却中用 CountDown 工具逐秒递减，结束后转可领取
function GroupRewardBillboardController:restartCountDown()
	-- 自增代号让上一个倒计时（若有）在下次 tick 时经 stopFlag 退出
	self._countToken += 1
	local token = self._countToken

	local readyAt = tonumber(localPlayer:GetAttribute(AttributeEnum.GroupRewardReadyAt)) or 0
	local remaining = math.max(0, math.floor(readyAt - os.time()))
	if remaining <= 0 then
		self:_showReady()
		return
	end

	startCountdown(remaining, function(timeLeft)
		if self._countToken ~= token then
			return
		end
		if timeLeft <= 0 then
			self:_showReady()
		else
			self:_showCooldown(timeLeft)
		end
	end, function()
		if self._countToken == token then
			self:_showReady()
		end
	end, function()
		return self._countToken ~= token
	end)
end

function GroupRewardBillboardController:init()
	if self._started then
		return
	end
	self._started = true

	-- 触碰 Group 但未加入群组时，服务端通知此处弹出加群提示
	Network.connectEvent(RemoteEventKey.GroupRewardPromptJoin, function()
		self:promptJoin()
	end)

	task.spawn(function()
		if not PlayerDataClient.hasLoaded() then
			PlayerDataClient.loaded:Wait()
		end

		local base = waitForMyBase()
		local main = waitForDescendant(base, GROUP_BILLBOARD_MAIN_PATH, 30)
		local cashLabel = main and main:WaitForChild("CashAmount", 10)
		local countLabel = main and main:WaitForChild("CountDown", 10)
		local buttons = base:FindFirstChild("Touch_Group")
		if not (cashLabel and cashLabel:IsA("TextLabel") and countLabel and countLabel:IsA("TextLabel")) then
			warn("[GroupRewardBillboardController] 未找到 Group/Billboard/Main 下 CashAmount/CountDown")
			return
		end
		self._cashLabel = cashLabel
		self._countLabel = countLabel

		-- Group_Model/.../Neon：递归查找，兼容 ButtonTouch 中间层
		local groupModel = buttons and buttons:FindFirstChild("Group_Model")
		local neon = groupModel and groupModel:FindFirstChild("Neon", true)
		if neon and neon:IsA("BasePart") then
			self._neon = neon
		end

		self:refreshCash()
		self:restartCountDown()

		-- 斧头数变化时刷新金额
		PlayerDataClient.getUpdateSignal(PlayerDataKey.AxeTycoon):Connect(function()
			self:refreshCash()
		end)

		-- 下次可领取时间变化（领取/重连）时重启倒计时
		localPlayer:GetAttributeChangedSignal(AttributeEnum.GroupRewardReadyAt):Connect(function()
			self:restartCountDown()
		end)
	end)
end

return GroupRewardBillboardController
