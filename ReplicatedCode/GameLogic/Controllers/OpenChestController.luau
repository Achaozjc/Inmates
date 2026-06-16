--!strict

--[[
	OpenChestController（客户端）
	开箱揭晓：宝箱 Shake×3 → ToOpen 播完播放 SFX/Success 并移除宝箱 → 展示斧头 → 自动落位。
--]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Network = require(ReplicatedStorage.ReplicatedCode.Framework.Core.Network)
local Janitor = require(ReplicatedStorage.ReplicatedCode.Framework.Packages.Janitor)
local EffectTool = require(ReplicatedStorage.ReplicatedCode.Framework.Effects.EffectTool)
local RemoteEventKey = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.RemoteEventKey)
local AxeConfig = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Configs.AxeConfig)
local ColorEnum = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Enums.ColorEnum)
local AnimationsEnum = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Enums.AnimationsEnum)
local arrangeModels = require(ReplicatedStorage.ReplicatedCode.GameLogic.Modules.OpenChestArrangeModels)

local AXE_DISPLAY_SECONDS = 3
local AXE_REVEAL_Y_OFFSET = 0.5 -- 斧头展示 Y 偏移（相对 chest 基础偏移 -1.5，与宝箱保持一致）
local AXE_REVEAL_ROTATION_OFFSET = CFrame.Angles(0, 0, 0)

local camera = Workspace.CurrentCamera

local Instances = ReplicatedStorage:WaitForChild("Instances")
local Prefabs = Instances:WaitForChild("Prefabs")
local ChestPrefabs = Prefabs:WaitForChild("Chest")
local AxePrefabs = Prefabs:FindFirstChild("Axe")
local EffectPrefabs = Prefabs:FindFirstChild("Effect")
local EffectFolder = Workspace:WaitForChild("DebrisFolder"):WaitForChild("EffectFolder")

local OpenChestEffectPrefab: BasePart? = EffectPrefabs and EffectPrefabs:FindFirstChild("OpenEgg") :: BasePart? or nil

local function disableCollisions(model: Model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			(d :: BasePart).CanCollide = false
		end
	end
end

local function resolveAxePrefab(axeCategory: string): Model?
	if not AxePrefabs then
		return nil
	end
	local prefab = AxePrefabs:FindFirstChild(axeCategory) or AxePrefabs:FindFirstChild("1")
	if prefab and prefab:IsA("Model") then
		return prefab
	end
	return nil
end

local function rarityColorSequence(axeCategory: string): ColorSequence
	local axeInfo = AxeConfig.Axes[axeCategory]
	local rarity = if axeInfo then axeInfo.rarity else 1
	local c = ColorEnum.SingleRarityColor[rarity] or Color3.new(1, 1, 1)
	return ColorSequence.new(c)
end

local function attachOpenEffect(axeModel: Model, colorSeq: ColorSequence)
	if not OpenChestEffectPrefab then
		return
	end
	local primaryPart = axeModel.PrimaryPart
	if not primaryPart then
		return
	end

	local effect = OpenChestEffectPrefab:Clone() :: BasePart
	-- 焊接前反向旋转特效 Part，抵消斧头展示 +90° 后的粒子朝向变化
	effect.CFrame = primaryPart.CFrame * AXE_REVEAL_ROTATION_OFFSET:Inverse()
	effect.Parent = axeModel

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = primaryPart
	weld.Part1 = effect
	weld.Parent = primaryPart

	EffectTool._setColor(effect, colorSeq)
	EffectTool._setEnabled(effect, true)
end

local OpenChestController = {
	_janitor = Janitor.new(),
	_chestModels = {} :: { Model },
	_axeModels = {} :: { Model },
	_busy = false,
}

function OpenChestController:_clearModels()
	for _, m in ipairs(self._chestModels) do
		pcall(m.Destroy, m)
	end
	for _, m in ipairs(self._axeModels) do
		pcall(m.Destroy, m)
	end
	table.clear(self._chestModels)
	table.clear(self._axeModels)
end

function OpenChestController:_renderPosition(models: { Model }, yOffset: number?, rotationOffset: CFrame?)
	self._janitor:Cleanup()

	local offsetY = yOffset or 0
	self._janitor:Add(
		RunService.RenderStepped:Connect(function()
			local cf = camera.CFrame
			local center = cf.Position + cf.LookVector * 5 + Vector3.new(0, -1 + offsetY, 0)
			local lookFrom = cf.Position
			arrangeModels(models, center, lookFrom, cf.RightVector, rotationOffset)
		end),
		"Disconnect"
	)
end

local function ensureAnimator(chestModel: Model): Animator?
	local animCtrl = chestModel:FindFirstChildOfClass("AnimationController")
	if not animCtrl then
		animCtrl = Instance.new("AnimationController")
		animCtrl.Parent = chestModel
	end
	local animator = animCtrl:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = animCtrl
	end
	return animator
end

local function loadAnimationTrack(animator: Animator, animId: number): (AnimationTrack?, Animation?)
	local anim = Instance.new("Animation")
	anim.AnimationId = "rbxassetid://" .. tostring(animId)
	local ok, track = pcall(function()
		return animator:LoadAnimation(anim)
	end)
	if ok and track then
		track.Priority = Enum.AnimationPriority.Action
		return track, anim
	end
	anim:Destroy()
	return nil, nil
end

local function playAnimationOnce(animator: Animator, animId: number): boolean
	local track, anim = loadAnimationTrack(animator, animId)
	if not track then
		return false
	end
	track.Looped = false
	track:Play()
	track.Stopped:Wait()
	track:Destroy()
	if anim then
		anim:Destroy()
	end
	return true
end

function OpenChestController:_destroyChestModels()
	for _, m in ipairs(self._chestModels) do
		pcall(m.Destroy, m)
	end
	table.clear(self._chestModels)
end

function OpenChestController:_playChestSequence(chestModel: Model): boolean
	chestModel.Parent = EffectFolder
	local animator = ensureAnimator(chestModel)
	if not animator then
		return false
	end

	local chestAnims = AnimationsEnum.Chest
	local playedAny = false

	for _ = 1, 3 do
		if playAnimationOnce(animator, chestAnims.Shake) then
			playedAny = true
		end
	end
	if playAnimationOnce(animator, chestAnims.ToOpen) then
		playedAny = true
	elseif chestModel.PrimaryPart then
		local tween = TweenService:Create(
			chestModel.PrimaryPart,
			TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Size = chestModel.PrimaryPart.Size * 1.4 }
		)
		tween:Play()
		tween.Completed:Wait()
		playedAny = true
	end

	return playedAny
end

function OpenChestController:_showAxeModels()
	if #self._axeModels == 0 then
		return
	end
	self:_renderPosition(self._axeModels, AXE_REVEAL_Y_OFFSET, AXE_REVEAL_ROTATION_OFFSET)
	for _, axeModel in ipairs(self._axeModels) do
		axeModel.Parent = EffectFolder
		-- 含 Humanoid 的 R6 模型挂入 Workspace 后引擎会强制打开 Torso 碰撞，需再次关闭
		disableCollisions(axeModel)
	end
end

function OpenChestController:_createModels(chestCategory: string, axeCategory: string)
	local chestPrefab = ChestPrefabs:FindFirstChild(chestCategory) :: Model?
	if chestPrefab then
		local chestModel = chestPrefab:Clone() :: Model
		disableCollisions(chestModel)
		chestModel:ScaleTo(0.45)
		chestModel.Parent = ReplicatedStorage
		table.insert(self._chestModels, chestModel)
	end

	local axePrefab = resolveAxePrefab(axeCategory)
	if axePrefab then
		local axeModel = axePrefab:Clone() :: Model
		disableCollisions(axeModel)
		axeModel:ScaleTo(0.75)
		axeModel.Parent = ReplicatedStorage
		table.insert(self._axeModels, axeModel)
		attachOpenEffect(axeModel, rarityColorSequence(axeCategory))
	end
end

function OpenChestController:_playAnim()
	if #self._chestModels > 0 then
		self:_renderPosition(self._chestModels)
		local chestModel = self._chestModels[1]
		self:_playChestSequence(chestModel)
		SoundService.SFX.Success:Play()
		self:_destroyChestModels()
	end

	self:_showAxeModels()
end

function OpenChestController:FinishShow()
	self._janitor:Cleanup()
	self:_clearModels()
	self._busy = false

	Network.fireServer(RemoteEventKey.ChestRevealDone)
end

function OpenChestController:OpenChest(chestCategory: string, axeCategory: string)
	if self._busy then
		self:FinishShow()
	end
	self._busy = true

	self._janitor:Cleanup()
	self:_clearModels()

	self:_createModels(chestCategory, axeCategory)

	if #self._chestModels == 0 and #self._axeModels == 0 then
		self:FinishShow()
		return
	end

	task.spawn(function()
		self:_playAnim()
		task.wait(AXE_DISPLAY_SECONDS)
		self:FinishShow()
	end)
end

function OpenChestController.start()
end

function OpenChestController.listen()
	Network.connectEvent(RemoteEventKey.Chest_OpenAnim, function(chestCategory: string, axeCategory: string)
		OpenChestController:OpenChest(chestCategory, axeCategory)
	end)
end

return OpenChestController
