--!strict

--[[
	木头生产服务（服务端权威，仅产出数据）。

	为每把已放置斧子用 TimerSystem 跑一个自循环计时器（周期 = AxeConfig.Axes[cat].cd，默认 4s）：
	到点产出 1 件对应木种 → 计入 TycoonState 堆叠区（受 GROUND_STACK_LIMIT 上限），
	在产木前 PRODUCE_ANIM_LEAD 秒 fire produceAnim（砍木动画），到点 fire produce（木材堆叠视觉）；
	两者均只发给基地主人（fireClient），其他玩家不渲染木材表现以节省带宽。

	斧子的出现/消失通过每秒 reconcile 与 BaseAssignmentService 的基地槽位同步：
	无论斧子是重连重建、购买还是合成产生，都会被自动接管/释放，无需各处显式调用。

	木材模型与堆叠效果全部在客户端完成，服务端只维护数据（见 TycoonState）。
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ReplicatedCode = ReplicatedStorage:WaitForChild("ReplicatedCode")
local ServerCode = ServerScriptService:WaitForChild("ServerCode")

local Network = require(ReplicatedCode.Framework.Core.Network)
local setInterval = require(ReplicatedCode.Framework.Utility.Time.SetInterval)
local TimerSystem = require(ReplicatedCode.Framework.Effects.TimerSystem)
local AxeConfig = require(ReplicatedCode.GameLogic.Shared.Configs.AxeConfig)
local RemoteEventKey = require(ReplicatedCode.GameLogic.SharedConstants.Keys.RemoteEventKey)
local BaseAssignmentService = require(ServerCode.GameLogic.Service.AxeTycoon.BaseAssignmentService)
local TycoonState = require(ServerCode.GameLogic.Modules.AxeTycoon.TycoonState)
local ChestProductionService = require(ServerCode.GameLogic.Service.AxeTycoon.ChestProductionService)

local RECONCILE_INTERVAL = 1 -- 每秒同步斧子集合
-- 砍木动画比实际产木提前的秒数（客户端 produceAnim / produce 分两阶段）
local PRODUCE_ANIM_LEAD = 1.3

type Producer = {
	timer: TimerSystem.Timer,
	userId: number,
	woodCategory: string,
	axeCategory: string,
	slotKey: string,
	animThread: thread?,
}

local WoodProductionService = {}

-- 斧子模型 -> 生产者
local producers: { [Model]: Producer } = {}
local started = false

local function cancelProduceAnim(producer: Producer)
	if producer.animThread then
		pcall(task.cancel, producer.animThread)
		producer.animThread = nil
	end
end

-- 在下一周期产木前 PRODUCE_ANIM_LEAD 秒通知客户端播放砍木动画
local function scheduleProduceAnim(producer: Producer, model: Model)
	cancelProduceAnim(producer)

	local info = AxeConfig.Axes[producer.axeCategory]
	if not info then
		return
	end

	local delay = math.max(0, info.cd - PRODUCE_ANIM_LEAD)
	producer.animThread = task.delay(delay, function()
		producer.animThread = nil
		if producers[model] ~= producer or not model.Parent then
			return
		end
		-- 仅发给基地主人：木材表现只对本人可见，节省其他客户端带宽
		local owner = Players:GetPlayerByUserId(producer.userId)
		if owner then
			Network.fireClient(RemoteEventKey.AxeTycoonSync, owner, {
				kind = "produceAnim",
				axe = model,
			})
		end
	end)
end

-- 释放某个斧子的生产者
local function removeProducer(model: Model)
	local producer = producers[model]
	if producer then
		cancelProduceAnim(producer)
		TimerSystem.untrack(producer.timer)
		producers[model] = nil
	end
end

-- 计时器到点：产木（仅数据）+ 通知客户端表现 + 续期
local function onComplete(model: Model)
	local producer = producers[model]
	if not producer then
		return
	end

	-- 斧子已被销毁（合成/清场/离开）则停止
	if not model.Parent then
		removeProducer(model)
		return
	end

	-- 产 1 件木头到堆叠区；满仓返回 0
	local added = TycoonState.addGroundWood(producer.userId, producer.woodCategory, 1)
	if added > 0 then
		-- 仅通知基地主人：该斧子产出一件木头（动画已在 produceAnim 中提前播放）
		local owner = Players:GetPlayerByUserId(producer.userId)
		if owner then
			Network.fireClient(RemoteEventKey.AxeTycoonSync, owner, {
				kind = "produce",
				axe = model,
				wood = producer.woodCategory,
			})
		end

		-- 产木同时按概率掉落对应等级宝箱（仅数据，表现在客户端）
		ChestProductionService.tryProduce(producer.userId, model, producer.axeCategory)
	end

	-- 续期：重置已用时并重挂完成回调，进入下一周期
	TimerSystem.setElapsedSeconds(producer.timer, 0)
	TimerSystem.setCompletionHandler(producer.timer, function()
		onComplete(model)
	end)

	scheduleProduceAnim(producer, model)
end

-- 为新出现的斧子创建生产者
local function addProducer(userId: number, slotKey: string, model: Model, category: string)
	local info = AxeConfig.Axes[category]
	if not info then
		warn(string.format("[WoodProductionService] 未知斧头 category=%s，跳过生产", tostring(category)))
		return
	end

	local timer = TimerSystem.new(info.cd, true)
	local producer: Producer = {
		timer = timer,
		userId = userId,
		woodCategory = info.wood,
		axeCategory = category,
		slotKey = slotKey,
	}
	producers[model] = producer

	TimerSystem.setCompletionHandler(timer, function()
		onComplete(model)
	end)

	scheduleProduceAnim(producer, model)
end

-- 同步：让 producers 与各玩家基地当前已放置斧子保持一致
local function reconcile()
	local present: { [Model]: boolean } = {}

	for _, player in Players:GetPlayers() do
		local baseObject = BaseAssignmentService.getBaseObject(player)
		if baseObject then
			for _, occupied in baseObject:getOccupiedSlots() do
				present[occupied.model] = true
				if not producers[occupied.model] then
					addProducer(player.UserId, occupied.key, occupied.model, occupied.category)
				end
			end
		end
	end

	-- 清理已消失的斧子
	for model in producers do
		if not present[model] or not model.Parent then
			removeProducer(model)
		end
	end
end

-- 玩家离开：清理其所有生产者与堆叠区数据
local function onPlayerRemoving(player: Player)
	for model, producer in producers do
		if producer.userId == player.UserId then
			removeProducer(model)
		end
	end
	TycoonState.clearGround(player.UserId)
end

-- 供 HUD / 背负后续读取堆叠区总数
function WoodProductionService.getGroundTotal(player: Player): number
	return TycoonState.getGroundTotal(player.UserId)
end

function WoodProductionService.start()
	if started then
		return
	end
	started = true

	setInterval(reconcile, RECONCILE_INTERVAL)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
end

return WoodProductionService
