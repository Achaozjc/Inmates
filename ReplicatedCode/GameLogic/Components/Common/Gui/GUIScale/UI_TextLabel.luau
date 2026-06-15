--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GUIScale = require(script.Parent)

local getViewportScale = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.UI.GetViewportScale)


local UI_TextLabel = setmetatable({}, {__index = GUIScale}) --继承父类
UI_TextLabel.__index = UI_TextLabel


export type ClassType = GUIScale.ClassType & {
	_oldSize: number,
}

function UI_TextLabel.new(instance: any): ClassType
	
	local self : any = GUIScale.new(instance)
	setmetatable(self, UI_TextLabel) 
	
	self._oldSize = instance:GetAttribute("size") or instance.TextSize
	instance:SetAttribute("size", self._oldSize)

	self:setup()

	return self
end



function UI_TextLabel.scale(self: ClassType)
	local minScale = getViewportScale()
	self._instance.TextSize = self._oldSize * minScale -- 设置UIScale的Scale属性
end



return UI_TextLabel

