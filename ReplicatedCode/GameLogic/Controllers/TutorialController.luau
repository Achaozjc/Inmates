--!strict

--[[
	新手教程控制器（纯客户端，软引导）。

	参考 spicy 项目 GUI_Tutorial 的"观察数据推进"思路：不改动任何玩法服务，
	只读取 PlayerData / 玩家属性判断每步是否完成，完成后经 Tutorial_StepComplete 上报落库。
	表现层 = 顶部提示卡片（GuideHintStyle）+ 目标按钮上的 Highlight 与弹跳箭头 Billboard
	+ 角色到目标的引导光束（CharacterPath）。

	步骤（顺序执行，已完成的标记直接跳过；重进可从中断处恢复）：
	  1. BuyAxe           触碰 BuyAxe_1 买第一把斧子      → ownedAxeCount > 0
	  2. CollectWood      站上堆叠区收木头                → carrying 非空（有自动收木通行证直接跳过）
	  3. DepositWood      触碰 Storage 卸木入库           → processorStock / PendingCash 出现
	  4. CollectCash      触碰 CollectMoney 领取现金      → PendingCash 出现后归零（有自动收钱通行证直接跳过）
	  5. UpgradeProcessor 触碰 Upgrade 升级处理机         → processorUpgradeCount 增加
	     （顶部文案立即展示；箭头/路径/高亮等 Cash 足够支付升级价后再出现）

	每步开始前先做"已达成"预检（如老玩家已有斧子），达成则静默上报不展示引导；
	仅当本次会话真正展示过引导时，结束才显示完成祝贺文案。
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Framework = ReplicatedStorage.ReplicatedCode.Framework
local GameLogic = ReplicatedStorage.ReplicatedCode.GameLogic

local Network = require(Framework.Core.Network)
local CharacterPath = require(Framework.Character.CharacterPath)
local PlayerDataClient = require(Framework.DataStore.PlayerDataClient)
local GuideHintStyle = require(Framework.UI.GuideHintStyle)
local AttributeEnum = require(GameLogic.Shared.Enums.AttributeEnum)
local ProcessorUpgradeConfig = require(GameLogic.Shared.Configs.ProcessorUpgradeConfig)
local CashKey = require(GameLogic.SharedConstants.Keys.CashKey)
local PlayerDataKey = require(GameLogic.SharedConstants.Keys.PlayerDataKey)
local RemoteEventKey = require(GameLogic.SharedConstants.Keys.RemoteEventKey)
local TutorialStepKey = require(GameLogic.SharedConstants.Keys.TutorialStepKey)

local localPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() :: Player

-- 完成判定轮询间隔（秒）；目标 Part 解析等待上限（秒）
local POLL_INTERVAL = 0.25
local TARGET_WAIT_TIMEOUT = 30
-- 完成祝贺文案停留时长（秒）
local FINISH_HOLD_SECONDS = 3

-- 箭头弹跳动画
local ARROW_BOUNCE_STUDS = 1.6
local ARROW_TWEEN = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

local TutorialController = {
	Name = "TutorialController",
	_started = false,
}

-- 当前世界标记（Highlight + 箭头 Billboard + 引导光束），切步/结束时销毁
local _markerInstances: { Instance } = {}
local _arrowTween: Tween? = nil
local _characterPath: CharacterPath.ClassType? = nil

-- ============================================================
-- 数据读取
-- ============================================================

local function getAxeData(): any
	local data = PlayerDataClient.get(PlayerDataKey.AxeTycoon)
	return if type(data) == "table" then data else {}
end

local function getOwnedAxeCount(): number
	return tonumber(getAxeData().ownedAxeCount) or 0
end

local function getCarryingTotal(): number
	local carrying = getAxeData().carrying
	if type(carrying) ~= "table" then
		return 0
	end
	local total = 0
	for _, count in carrying do
		total += tonumber(count) or 0
	end
	return total
end

local function getProcessorStock(): number
	return tonumber(getAxeData().processorStock) or 0
end

local function getUpgradeCount(): number
	return tonumber(getAxeData().processorUpgradeCount) or 0
end

local function getPendingCash(): number
	local currency = PlayerDataClient.get(PlayerDataKey.Currency)
	if type(currency) ~= "table" then
		return 0
	end
	return tonumber(currency[CashKey.PendingCash]) or 0
end

local function getCash(): number
	local currency = PlayerDataClient.get(PlayerDataKey.Currency)
	if type(currency) ~= "table" then
		return 0
	end
	return math.floor(tonumber(currency[CashKey.Cash]) or 0)
end

local function canAffordProcessorUpgrade(): boolean
	local cost = ProcessorUpgradeConfig.getUpgradeCost(getUpgradeCount())
	return getCash() >= cost
end

-- 读取教程完成标记（newbie 缺失时视为全未完成）
local function getNewbieFlag(flag: string): boolean
	local tutorial = PlayerDataClient.get(PlayerDataKey.Tutorial)
	local newbie = if type(tutorial) == "table" then tutorial.newbie else nil
	return type(newbie) == "table" and newbie[flag] == true
end

local function ownsGamepass(attribute: string): boolean
	return localPlayer:GetAttribute(attribute) == true
end

-- ============================================================
-- 目标 Part 解析（本地玩家自己的基地）
-- ============================================================

local function findMyBase(): Folder?
	local world = Workspace:FindFirstChild("World")
	if not world then
		return nil
	end
	for _, child in world:GetChildren() do
		if child:IsA("Folder") and string.match(child.Name, "^Base_%d+$") then
			if child:GetAttribute(AttributeEnum.OwnerId) == localPlayer.UserId then
				return child :: Folder
			end
		end
	end
	return nil
end

-- 在自己基地内解析 TouchedButtons 下的按钮 Part
local function findBaseButton(buttonName: string,parentName:string): BasePart?
	local base = findMyBase()
	parentName = parentName or "Touch_Merge&Buy"
	local buttons = base and base:FindFirstChild(parentName)
	local part = buttons and buttons:FindFirstChild(buttonName)
	return if part and part:IsA("BasePart") then part else nil
end

-- 堆叠区 Part：优先 AxeMachine/TouchedStacking，缺失时基地内递归查找（与 WoodCarryService 一致）
local function findStackingPart(): BasePart?
	local base = findMyBase()
	if not base then
		return nil
	end
	local axeMachine = base:FindFirstChild("InmateMachine")
	local stacking = axeMachine and axeMachine:FindFirstChild("TouchedStacking")
	if stacking and stacking:IsA("BasePart") then
		return stacking
	end
	local found = base:FindFirstChild("TouchedStacking", true)
	return if found and found:IsA("BasePart") then found else nil
end

-- 轮询等待目标 Part 就绪（基地分配可能晚于客户端启动）
local function waitForPart(resolve: () -> BasePart?): BasePart?
	local deadline = os.clock() + TARGET_WAIT_TIMEOUT
	while os.clock() < deadline do
		local part = resolve()
		if part and part:IsDescendantOf(Workspace) then
			return part
		end
		task.wait(0.5)
	end
	return resolve()
end

-- ============================================================
-- 世界标记：目标 Part 高亮 + 弹跳箭头 + 角色引导光束
-- ============================================================

-- 引导光束落点：目标 Part 顶面中心，与箭头高度对齐
local function getGuideTargetCFrame(part: BasePart): CFrame
	return part.CFrame * CFrame.new(0, part.Size.Y * 0.5 + 2, 0)
end

local function hideCharacterPath()
	if _characterPath then
		_characterPath:destroy()
		_characterPath = nil
	end
end

local function showCharacterPath(part: BasePart)
	hideCharacterPath()
	local path = CharacterPath.new()
	_characterPath = path
	path:setTarget(getGuideTargetCFrame(part))
end

local function hideMarker()
	if _arrowTween then
		_arrowTween:Cancel()
		_arrowTween = nil
	end
	hideCharacterPath()
	for _, instance in _markerInstances do
		instance:Destroy()
	end
	table.clear(_markerInstances)
end

local function showMarker(part: BasePart)
	hideMarker()
	showCharacterPath(part)

	local highlight = Instance.new("Highlight")
	highlight.Name = "TutorialHighlight"
	highlight.FillColor = Color3.fromRGB(255, 200, 60)
	highlight.FillTransparency = 0.65
	highlight.OutlineColor = Color3.fromRGB(255, 235, 130)
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Adornee = part
	highlight.Parent = part
	table.insert(_markerInstances, highlight)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "TutorialArrow"
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromScale(5, 5)
	billboard.MaxDistance = 300
	billboard.StudsOffsetWorldSpace = Vector3.new(0, part.Size.Y * 0.5 + 5, 0)
	billboard.Adornee = part
	billboard.Parent = part
	table.insert(_markerInstances, billboard)

	local arrow = Instance.new("TextLabel")
	arrow.Name = "Glyph"
	arrow.Size = UDim2.fromScale(1, 1)
	arrow.BackgroundTransparency = 1
	arrow.Font = Enum.Font.GothamBlack
	arrow.Text = "v"
	arrow.TextColor3 = Color3.fromRGB(255, 200, 60)
	arrow.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	arrow.TextStrokeTransparency = 0
	arrow.TextScaled = true
	arrow.Parent = billboard

	-- 箭头上下弹跳，提示玩家走向目标
	local tween = TweenService:Create(billboard, ARROW_TWEEN, {
		StudsOffsetWorldSpace = billboard.StudsOffsetWorldSpace - Vector3.new(0, ARROW_BOUNCE_STUDS, 0),
	})
	_arrowTween = tween
	tween:Play()
end

-- ============================================================
-- 步骤状态机
-- ============================================================

local function reportStepDone(stepKey: string)
	Network.fireServer(RemoteEventKey.Tutorial_StepComplete, stepKey)
end

type Step = {
	key: string, -- TutorialStepKey
	flag: string, -- PlayerData.Tutorial.newbie 标记字段
	hintText: string, -- 引导文案（纯英文）
	resolveTarget: () -> BasePart?, -- 引导目标 Part
	shouldSkip: (() -> boolean)?, -- 跳过条件（如已拥有自动通行证）
	isAlreadyDone: () -> boolean, -- 预检：未引导也视为已达成（老玩家快进）
	makeIsDone: () -> () -> boolean, -- 构造本步完成判定（可携带步内状态）
	shouldShowMarker: (() -> boolean)?, -- 为 false 时隐藏世界标记（默认 true）
}

local STEPS: { Step } = {
	{
		key = TutorialStepKey.BuyAxe,
		flag = "buyAxeDone",
		hintText = "Step on the Buy Button to hire your first Lumberjack!",
		resolveTarget = function()
			return findBaseButton("BuyAxe_1")
		end,
		isAlreadyDone = function()
			return getOwnedAxeCount() > 0
		end,
		makeIsDone = function()
			return function()
				return getOwnedAxeCount() > 0
			end
		end,
	},
	{
		key = TutorialStepKey.CollectWood,
		flag = "collectWoodDone",
		hintText = "Lumberjacks chop wood! Wait for the wood and collect it!",
		resolveTarget = findStackingPart,
		shouldSkip = function()
			return ownsGamepass(AttributeEnum.GamepassAutoCollectWood)
		end,
		isAlreadyDone = function()
			-- 身上已有木头，或已经入过库（库存/待收现金存在）都说明收集过
			return getCarryingTotal() > 0 or getProcessorStock() > 0 or getPendingCash() > 0
		end,
		makeIsDone = function()
			-- 堆叠区与 Storage 相邻时，捡起与入库可能在两次轮询之间连续发生，
			-- 因此入库痕迹（库存/待收现金）同样视为已收集，避免卡步
			return function()
				return getCarryingTotal() > 0 or getProcessorStock() > 0 or getPendingCash() > 0
			end
		end,
	},
	{
		key = TutorialStepKey.DepositWood,
		flag = "depositWoodDone",
		hintText = "Carry your stack of wood and deposit it for processing!",
		resolveTarget = function()
			return findBaseButton("Storage","Touch_Collection")
		end,
		isAlreadyDone = function()
			return getProcessorStock() > 0 or getPendingCash() > 0
		end,
		makeIsDone = function()
			return function()
				return getProcessorStock() > 0 or getPendingCash() > 0
			end
		end,
	},
	{
		key = TutorialStepKey.CollectCash,
		flag = "collectCashDone",
		hintText = "Now step here to collect your cash!",
		resolveTarget = function()
			return findBaseButton("CollectMoney","Touch_Collection")
		end,
		shouldSkip = function()
			return ownsGamepass(AttributeEnum.GamepassAutoCollectCash)
		end,
		isAlreadyDone = function()
			return false
		end,
		makeIsDone = function()
			-- 完成判定：待收现金出现过、随后归零（玩家触碰 CollectMoney 全额领取）
			local seenPending = getPendingCash() > 0
			return function()
				local pending = getPendingCash()
				if pending > 0 then
					seenPending = true
					return false
				end
				return seenPending
			end
		end,
	},
	{
		key = TutorialStepKey.UpgradeProcessor,
		flag = "upgradeDone",
		hintText = "Step on the upgrade button to increase your cash rate!",
		resolveTarget = function()
			return findBaseButton("Upgrade","Touch_Collection")
		end,
		isAlreadyDone = function()
			return getUpgradeCount() > 0
		end,
		makeIsDone = function()
			local startCount = getUpgradeCount()
			return function()
				return getUpgradeCount() > startCount
			end
		end,
		shouldShowMarker = canAffordProcessorUpgrade,
	},
}

-- 执行单个引导步骤：展示标记与文案 → 轮询完成 → 清理。返回是否真正展示过引导。
local function runGuidedStep(step: Step): boolean
	local isDone = step.makeIsDone()

	GuideHintStyle.show()
	GuideHintStyle.setMessage(step.hintText)

	-- 异步解析目标并按条件挂标记（解析期间不阻塞完成判定；目标缺失时仅保留文案）
	local stepActive = true
	local markerShown = false
	task.spawn(function()
		local part = waitForPart(step.resolveTarget)
		if not part then
			return
		end
		while stepActive do
			local shouldShowMarker = not step.shouldShowMarker or step.shouldShowMarker()
			if shouldShowMarker and not markerShown then
				showMarker(part)
				markerShown = true
			elseif not shouldShowMarker and markerShown then
				hideMarker()
				markerShown = false
			end
			task.wait(POLL_INTERVAL)
		end
	end)

	while not isDone() do
		task.wait(POLL_INTERVAL)
	end

	stepActive = false
	hideMarker()
	return true
end

local function runTutorial()
	-- 等玩家数据加载完成再判断进度
	if not PlayerDataClient.hasLoaded() then
		PlayerDataClient.loaded:Wait()
	end

	-- 全部已完成则不做任何事（绝大多数老玩家在此直接返回）
	local allDone = true
	for _, step in STEPS do
		if not getNewbieFlag(step.flag) then
			allDone = false
			break
		end
	end
	if allDone then
		return
	end

	local guidedAny = false
	for _, step in STEPS do
		if getNewbieFlag(step.flag) then
			continue
		end
		if (step.shouldSkip and step.shouldSkip()) or step.isAlreadyDone() then
			-- 通行证跳过或老玩家已达成：静默上报，不展示引导
			reportStepDone(step.key)
			continue
		end
		runGuidedStep(step)
		reportStepDone(step.key)
		guidedAny = true
	end

	-- 仅本次会话真正引导过才显示完成祝贺
	if guidedAny then
		GuideHintStyle.setMessage("Tutorial complete! Get to choppin, lumber boss!")
		task.wait(FINISH_HOLD_SECONDS)
	end
	GuideHintStyle.hide()
end

function TutorialController.start()
	if TutorialController._started then
		return
	end
	TutorialController._started = true

	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
	GuideHintStyle.init(playerGui)

	task.spawn(runTutorial)
end

return TutorialController
