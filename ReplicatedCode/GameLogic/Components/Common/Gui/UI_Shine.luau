--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UITween = require(ReplicatedStorage.ReplicatedCode.Framework.UI.UITween)


local SHEEN_DURATION = 2

local UI_Shine = {}
UI_Shine.__index = UI_Shine

export type ClassType = typeof(setmetatable({} :: {
	_gradient: UIGradient,
	_tween: Tween

}, UI_Shine))

function UI_Shine.new(gradient: UIGradient): ClassType
	local self = {
		_gradient = gradient,

	}

	setmetatable(self, UI_Shine)

	local delay = 3
	self._tween = UITween.offset(
		self._gradient,
		Vector2.new(-1.5, 0),
		SHEEN_DURATION,
		Enum.EasingStyle.Sine,
		Enum.EasingDirection.InOut,
		-1,
		false,
		delay
	)

	self:setup()

	self:listen()

	return self
end

function UI_Shine.setup(self: ClassType)


end


function UI_Shine.scale(self: ClassType)

end



function UI_Shine.listen(self: ClassType)	

end



function UI_Shine.destroy(self: ClassType)
	self._tween:Cancel()
	self._tween:Destroy()
end

return UI_Shine
