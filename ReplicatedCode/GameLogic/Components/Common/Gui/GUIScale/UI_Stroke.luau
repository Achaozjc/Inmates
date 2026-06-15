--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GUIScale = require(script.Parent)

local getViewportScale = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.UI.GetViewportScale)


local UI_Stroke = setmetatable({}, {__index = GUIScale}) --继承父类
UI_Stroke.__index = UI_Stroke


export type ClassType = GUIScale.ClassType & {
	_oldSize: number,
}

function UI_Stroke.new(instance: any): ClassType
	
	local self : any = GUIScale.new(instance)
	setmetatable(self, UI_Stroke) 
	
	self._oldSize = (instance:GetAttribute("size") or instance.Thickness) :: number
	instance:SetAttribute("size", self._oldSize)

	self:setup()

	return self
end



function UI_Stroke.scale(self: ClassType)
	local minScale = getViewportScale()
	self._instance.Thickness = self._oldSize * minScale -- 设置UIScale的Scale属性
end



return UI_Stroke

