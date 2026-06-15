--!strict

--[[
	Shows an animation whenever coins get added to player's data to make it obvious
	to the user they got coins.

	Once the projectile lands, the coin indicator plays a "catch" animation (momentarily resizes larger)
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")



local Connections = require(ReplicatedStorage.ReplicatedCode.Framework.Infrastructure.Classes.Connections)

local getInstance = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Instance.GetInstance)
local getCodeAsset = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Instance.GetCodeAsset)

local CATCH_SIZE_MULTIPLIER = 1.25 -- Coin indicator gets resized by this amount as a "Catch" animation
local CATCH_TWEEN_INFO = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true)
local TOTAL_DELTA_TWEEN_INFO = TweenInfo.new(3, Enum.EasingStyle.Quint)
local TOTAL_DELTA_OFFSET = UDim2.fromScale(0, -6)
local RichTextCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.RichTextCategory)
local CashKey = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.CashKey)


local prefabFolder: Folder = getCodeAsset("UI", "CashAnimator")
local deltaPrefab: TextLabel = (getInstance(prefabFolder, "CashDeltaPrefab") :: any) :: TextLabel
local addCoinsSound = (getInstance(SoundService, "SFX", "Coins") :: any) :: AudioPlayer
local removeCoinsSound = (getInstance(SoundService, "SFX", "Purchase") :: any) :: AudioPlayer
local ShowUnitNum = require(ReplicatedStorage.ReplicatedCode.Framework.UI.ShowUnitNum)

local format = string.format


local CashAnimator = {}
CashAnimator.__index = CashAnimator

export type ClassType = typeof(setmetatable(
	{} :: {
		_initialValueSet: boolean,
		_isUpdatePending: boolean,
		_isDestroyed: boolean,
		_oldCoinCount: number,
		_screenGui: ScreenGui,
		_coinBackground: Frame,
		_amountTextLabel: TextLabel,
		_prefix: string,
		--_projectileIconQueue: ProjectileIconQueue.ClassType,
		_connections: Connections.ClassType,
	},
	CashAnimator
))

function CashAnimator.new(amountTextLabel :TextLabel, coinBackground :Frame, coinIndicatorScreenGui: ScreenGui, prefix : string?, cashKey: CashKey.EnumType?): ClassType
	local self = {
		_initialValueSet = false,
		_isUpdatePending = false,
		_isDestroyed = false,
		_oldCoinCount = 0,
		_screenGui = coinIndicatorScreenGui,
		_coinBackground = coinBackground,
		_amountTextLabel = amountTextLabel,
		_prefix = prefix or RichTextCategory.number,
		--_projectileIconQueue = ProjectileIconQueue.new(coinIndicatorScreenGui, coinBackground),
		_connections = Connections.new(),
	}

	setmetatable(self, CashAnimator)

	self:_listenForIconCompleted()

	return self
end



function CashAnimator._update(self: ClassType, coins :number)
	task.spawn(function()
		-- The update waits until the coin indicator is visible. In order to avoid triggering unnecessary duplicate updates,
		-- we use this _isUpdatePending debounce flag. When the first update thread
		-- resumes, it calculates a total diff since the last update, so no later deltas are lost.
		if self._isUpdatePending then
			return
		end

		self._isUpdatePending = true
		self:_waitForVisibleAsync()
		self._isUpdatePending = false

		if self._isDestroyed then
			return
		end

	
		self._amountTextLabel.Text = format(self._prefix, ShowUnitNum(coins))
		
		

		if self._initialValueSet then
			-- Get coin delta since last update
			local coinDelta = self:_getNextCoinDelta(coins) -- Updates old data to diff next time
			-- Only animate the delta if it's not the initial data load
			self:_animateDelta(coinDelta)
		else
			self._oldCoinCount = coins
			self._initialValueSet = true
		end
	end)
end

function CashAnimator._waitForVisibleAsync(self: ClassType)
	while not self._screenGui.Enabled do
		self._screenGui:GetPropertyChangedSignal("Enabled"):Wait()
	end
end

function CashAnimator._listenForIconCompleted(self: ClassType)
	--local coinIndicatorCatchTween = TweenService:Create(self._coinBackground, CATCH_TWEEN_INFO, {
	--	Size = UDim2.fromScale(
	--		self._coinBackground.Size.X.Scale * CATCH_SIZE_MULTIPLIER,
	--		self._coinBackground.Size.Y.Scale * CATCH_SIZE_MULTIPLIER
	--	),
	--})

	--local iconCompletedConnection = self._projectileIconQueue.iconCompleted:Connect(function()
	--	coinIndicatorCatchTween:Play()
	--end)

	--self._connections:add(iconCompletedConnection)
end

function CashAnimator._animateDelta(self: ClassType, coinDelta: number)
	if coinDelta == 0 then
		return
	end

	local sound = coinDelta > 0 and addCoinsSound or removeCoinsSound
	sound:Play()


	--self._projectileIconQueue:animateDeltas({ [coinPrefab] = coinDelta })

	local deltaElement = deltaPrefab:Clone()
	local prefix = coinDelta > 0 and "+" or "-"

	deltaElement.Text = prefix .. ShowUnitNum(math.abs(coinDelta))
	deltaPrefab.TextColor3 = self._amountTextLabel.TextColor3
	deltaElement.Parent = self._amountTextLabel

	local tween = TweenService:Create(
		deltaElement,
		TOTAL_DELTA_TWEEN_INFO,
		{ Position = TOTAL_DELTA_OFFSET, TextTransparency = 1, TextStrokeTransparency = 1 }
	)

	task.spawn(function()
		tween:Play()
		tween.Completed:Wait()
		deltaElement:Destroy()
	end)
end

function CashAnimator._getNextCoinDelta(self: ClassType, coins :number)
	local newCount = coins
	local oldCount = self._oldCoinCount

	-- Update the cached count to compare against next time this function is called
	self._oldCoinCount = newCount

	return newCount - oldCount
end

function CashAnimator.destroy(self: ClassType)
	--self._projectileIconQueue:destroy()
	self._isDestroyed = true

	self._connections:disconnect()
end

return CashAnimator

