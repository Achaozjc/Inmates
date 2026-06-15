--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GUIScale = require(script.Parent)

local getViewportScale = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.UI.GetViewportScale)


local UI_TextSizeConstraint = setmetatable({}, {__index = GUIScale}) --继承父类
UI_TextSizeConstraint.__index = UI_TextSizeConstraint


export type ClassType = GUIScale.ClassType & {
	_oldSize: number,
}

function UI_TextSizeConstraint.new(instance: any): ClassType
	
	local self : any = GUIScale.new(instance)
	setmetatable(self, UI_TextSizeConstraint) 
	
	self._oldSize = instance:GetAttribute("size") or instance.MaxTextSize
	instance:SetAttribute("size", self._oldSize)
	instance.MinTextSize = 1

	self:setup()

	return self
end



function UI_TextSizeConstraint.scale(self: ClassType)
	local minScale = getViewportScale()
	self._instance.MaxTextSize = self._oldSize * minScale -- 设置UIScale的Scale属性
end



return UI_TextSizeConstraint

