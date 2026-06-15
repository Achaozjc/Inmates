--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")


local Connections = require(ReplicatedStorage.ReplicatedCode.Framework.Infrastructure.Classes.Connections)

local tweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

local SCALE_FACTOR = 0.9

local UI_Button = {}
UI_Button.__index = UI_Button

export type ClassType = typeof(setmetatable({} :: {
	_button: GuiObject,
	_tweenIn: Tween,
	_tweenOut: Tween,
	_connections: Connections.ClassType,
	
}, UI_Button))

function UI_Button.new(instance: GuiObject): ClassType
	local self = {
		_button = instance,
		_connections = Connections.new(),
	}

	setmetatable(self, UI_Button)
	
	local oldSize = instance.Size

	self._tweenIn = TweenService:Create(instance, tweenInfo , {
		Size = UDim2.new(
			oldSize.X.Scale / SCALE_FACTOR,
			oldSize.X.Offset / SCALE_FACTOR,
			oldSize.Y.Scale / SCALE_FACTOR,
			oldSize.Y.Offset / SCALE_FACTOR
		),
	})

	self._tweenOut = TweenService:Create(instance, tweenInfo, {
		Size = oldSize
	})	

	self:listen()

	return self
end

function UI_Button.setup(self: ClassType)

	
end


-- 播放按钮点击音效
function UI_Button._playClickSound(self: ClassType)
	local sfx = SoundService:FindFirstChild("SFX")
	local sound = sfx and sfx:FindFirstChild("Button")
	if sound and sound:IsA("Sound") then
		SoundService:PlayLocalSound(sound)
	end
end


function UI_Button._onHover(self: ClassType, isHovering: boolean)
	if isHovering then
		self._tweenIn:Play()
	else
		self._tweenOut:Play()
	end
end


function UI_Button.listen(self: ClassType)	
	local mouseEnterConnection = self._button.MouseEnter:Connect(function()
		self:_onHover(true)
	end)

	local mouseLeaveConnection = self._button.MouseLeave:Connect(function()
		self:_onHover(false)
	end)

	self._connections:add(mouseEnterConnection, mouseLeaveConnection)

	-- 仅 GuiButton 才有 Activated 事件
	local button = self._button
	if button:IsA("GuiButton") then
		local clickConnection = button.Activated:Connect(function()
			self:_playClickSound()
		end)
		self._connections:add(clickConnection)
	end
end



function UI_Button.destroy(self: ClassType)
	self._connections:disconnect()
	self._tweenIn:Cancel()
	self._tweenIn:Destroy()
	self._tweenOut:Cancel()
	self._tweenOut:Destroy()
end

return UI_Button

