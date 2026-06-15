
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local TweenGroup = require(ReplicatedStorage.ReplicatedCode.Framework.Infrastructure.Classes.TweenGroup)


local TWEEN_INFO = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local OFFSET = UDim2.fromScale(0, 0.3)

local MenuTween = {}
MenuTween.__index = MenuTween

export type ClassType = typeof(setmetatable(
	{} :: {
		_instance: Frame,
		_originalPos : UDim2,
		_tween: TweenGroup.ClassType,
	
	},
	MenuTween
))

function MenuTween.new(instance:Frame): ClassType
	local self = {
		_instance = instance,
		_originalPos = instance.Position

	}
	setmetatable(self, MenuTween)
	
	
	self._tween = TweenGroup.new(
		TweenService:Create(self._instance, TWEEN_INFO, {Position = self._originalPos})
	)


	return self
end




function MenuTween.doTween(self: ClassType)
	self._instance.Position = self._originalPos + OFFSET
	self._tween:play()
end



function MenuTween.destroy(self: ClassType)

end

return MenuTween

