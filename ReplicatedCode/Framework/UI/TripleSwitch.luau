local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Janitor = require(ReplicatedStorage.ReplicatedCode.Framework.Packages.Janitor)
local Network = require(ReplicatedStorage.ReplicatedCode.Framework.Core.Network)
local RemoteFunctionName = require(ReplicatedStorage.ReplicatedCode.Framework.Core.Network.RemoteName.RemoteFunctionName)
local NetSignals = require(ReplicatedStorage.ReplicatedCode.Framework.Core.Network.NetSignals)
local TriggerSignalCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.TriggerSignalCategory)
local NotifyCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.NotifyCategory)
local AudioController = require(ReplicatedStorage.ReplicatedCode.GameLogic.Controllers.AudioController)
local Signal = require(ReplicatedStorage.ReplicatedCode.Framework.Packages.Signal)

local TWEEN_INFO = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local COLOR_ACTIVE_BG = Color3.fromRGB(17, 255, 0)
local COLOR_ACTIVE_TEXT = Color3.fromRGB(0, 0, 0)
local COLOR_INACTIVE_BG = Color3.fromRGB(40, 40, 40)
local COLOR_INACTIVE_TEXT = Color3.fromRGB(180, 180, 180)

local TripleSwitch = {}
TripleSwitch.__index = TripleSwitch

export type ClassType = typeof(setmetatable(
	{} :: {
		_instance: Frame,
		_janitor: Janitor.Janitor,
		_value: number,
		_key: string?,
		_buttons: { TextButton },
		_labels: { string },
		_change: Signal.ClassType,
	},
	TripleSwitch
))

-- labels: 三档显示文字，如 {"S", "M", "L"}
-- value: 默认选中档位 (1/2/3)
function TripleSwitch.new(key: string?, labels: { string }?): ClassType
	local displayLabels = labels or { "S", "M", "L" }

	local frame = Instance.new("Frame")
	frame.Name = "TripleSwitch"
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundTransparency = 1

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 4)
	layout.Parent = frame

	local buttons = {} :: { TextButton }
	for i = 1, 3 do
		local btn = Instance.new("TextButton")
		btn.Name = "Option" .. i
		btn.Size = UDim2.new(0.3, 0, 0.85, 0)
		btn.BackgroundColor3 = COLOR_INACTIVE_BG
		btn.TextColor3 = COLOR_INACTIVE_TEXT
		btn.Text = displayLabels[i]
		btn.Font = Enum.Font.GothamBold
		btn.TextScaled = true
		btn.AutoButtonColor = false
		btn.Parent = frame

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.3, 0)
		corner.Parent = btn

		local padding = Instance.new("UIPadding")
		padding.PaddingTop = UDim.new(0.1, 0)
		padding.PaddingBottom = UDim.new(0.1, 0)
		padding.Parent = btn

		buttons[i] = btn
	end

	local self = setmetatable({
		_instance = frame,
		_janitor = Janitor.new(),
		_value = 2,
		_key = key or nil,
		_buttons = buttons,
		_labels = displayLabels,
		_change = Signal.new(),
	}, TripleSwitch)

	self:_updateVisual()
	self:_listen()

	return self
end

function TripleSwitch._setParent(self: ClassType, parent: Instance)
	self._instance.Parent = parent
end

function TripleSwitch._set(self: ClassType, value: number)
	local clamped = math.clamp(math.round(value), 1, 3)
	if clamped == self._value then
		return
	end
	self._value = clamped
	self:_updateVisual()
end

function TripleSwitch._updateVisual(self: ClassType)
	for i, btn in ipairs(self._buttons) do
		local active = (i == self._value)
		TweenService:Create(btn, TWEEN_INFO, {
			BackgroundColor3 = if active then COLOR_ACTIVE_BG else COLOR_INACTIVE_BG,
			TextColor3 = if active then COLOR_ACTIVE_TEXT else COLOR_INACTIVE_TEXT,
		}):Play()
	end
end

function TripleSwitch._listen(self: ClassType)
	for i, btn in ipairs(self._buttons) do
		self._janitor:Add(btn.Activated:Connect(function()
			if i == self._value then
				return
			end
			self._value = i
			self:_updateVisual()
			AudioController.playSFX("Select1")
			self._change:Fire(i)

			if self._key then
				local _requestSuccess, requestResult, failureReason =
					Network.invokeServerAsync(RemoteFunctionName.Change_Settings, self._key, i)
				if not requestResult then
					self:_set(requestResult)
					NetSignals.getSignal(TriggerSignalCategory.Client.notify):Fire(failureReason, NotifyCategory.Warn)
				end
			end
		end), "Disconnect")
	end
end

function TripleSwitch.destroy(self: ClassType)
	self._janitor:Destroy()
	self._change:DisconnectAll()
	self._instance:Destroy()
end

return TripleSwitch
