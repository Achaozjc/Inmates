
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local TweenGroup = require(ReplicatedStorage.ReplicatedCode.Framework.Infrastructure.Classes.TweenGroup)
local getInstance = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Instance.GetInstance)
local getCodeAsset = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Instance.GetCodeAsset)

local player = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() ::Player
local Button = require(ReplicatedStorage.ReplicatedCode.Framework.UI.Button)

local Network = require(ReplicatedStorage.ReplicatedCode.Framework.Core.Network)
local RemoteFunctionName = require(ReplicatedStorage.ReplicatedCode.Framework.Core.Network.RemoteName.RemoteFunctionName)
local Janitor = require(ReplicatedStorage.ReplicatedCode.Framework.Packages.Janitor)
local NetSignals = require(ReplicatedStorage.ReplicatedCode.Framework.Core.Network.NetSignals)
local TriggerSignalCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.TriggerSignalCategory)
local AudioController = require(ReplicatedStorage.ReplicatedCode.GameLogic.Controllers.AudioController)
local NotifyCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.NotifyCategory)


local prefabFolder: Folder = getCodeAsset("UI", "SwitchButton")
local switchButtonPrefab = (getInstance(prefabFolder, "SwitchButton") :: any) :: GuiButton

local TWEEN_INFO = TweenInfo.new(0.2)

local SwitchButton = {}
SwitchButton.__index = SwitchButton

export type ClassType = typeof(setmetatable(
	{} :: {
		_instance: Frame,
		_janitor: Janitor.Janitor,
		_button: Button.ClassType,
		_tweenOnGroup: TweenGroup.ClassType?,
		_tweenOffGroup: TweenGroup.ClassType?,
		_label: TextLabel,
		_value : boolean,
		_key : string
	
	},
	SwitchButton
))

function SwitchButton.new(key: string?): ClassType
	local self = {
	
		_instance = switchButtonPrefab:Clone(),
		_janitor = Janitor.new(),
	
		_value = false,
	
	
	}
	setmetatable(self, SwitchButton)
	

	self._button = Button.new(self._instance)
	self._key = key or nil
	self._label = self._instance.TextLabel
	
	
	
	self:_setupTweens()
	self:_doTween()
	self:_listen()
	return self
end


function SwitchButton._setParent(self: ClassType, parent)
	self._instance.Parent = parent
end


function SwitchButton._setupTweens(self: ClassType)
	local buttonInstance = self._instance:FindFirstChild("Circle")
	
	self._tweenOnGroup = TweenGroup.new(
		TweenService:Create(self._instance, TWEEN_INFO, { BackgroundColor3 = Color3.fromRGB(3, 50, 0) }),
		TweenService:Create(buttonInstance, TWEEN_INFO, {BackgroundColor3 = Color3.fromRGB(17, 255, 0), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5)})
		
		)


	self._tweenOffGroup = TweenGroup.new(
		TweenService:Create(self._instance, TWEEN_INFO, { BackgroundColor3 = Color3.fromRGB(48, 20, 22) }),
		TweenService:Create(buttonInstance, TWEEN_INFO, {BackgroundColor3 = Color3.fromRGB(237, 67, 67), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5)})

	)
end

function SwitchButton._doTween(self: ClassType)
	if self._value then
		if self._tweenOnGroup then
			self._tweenOnGroup:play()
		end	
		self._label.Text = "On"
		self._label.TextXAlignment = Enum.TextXAlignment.Left
		self._label.TextColor3 = Color3.fromRGB(17, 255, 0)
	else
		if self._tweenOffGroup then
			self._tweenOffGroup:play()
		end
		self._label.Text = "Off"
		self._label.TextXAlignment = Enum.TextXAlignment.Right
		self._label.TextColor3 = Color3.fromRGB(237, 67, 67)
	end
	AudioController.playSFX("Select1")
	
end


function SwitchButton._listen(self: ClassType)
	
	
	if self._key then  --有key才传值
		self._janitor:Add(self._button.activated:Connect(function()
			self:_switch()
			local requestSuccess, requestResult, failureReason = Network.invokeServerAsync(RemoteFunctionName.Change_Settings, self._key, self._value)		
			if not requestResult then
				self:_set(requestResult)
				NetSignals.getSignal(TriggerSignalCategory.Client.notify):Fire(failureReason ,NotifyCategory.Warn)
			end
		end),"Disconnect") 
	end
end


function SwitchButton._switch(self: ClassType)
	self._value = not self._value
	self:_doTween()
end

function SwitchButton._set(self: ClassType, bool: boolean)
	self._value = bool
	self:_doTween()
end



function SwitchButton.destroy(self: ClassType)
	self._janitor:Destroy()
	self._button:destroy()
	self._instance:Destroy()
end

return SwitchButton
