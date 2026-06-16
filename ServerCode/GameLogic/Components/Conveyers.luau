
local FORCE = 10

local Conveyers = {}
Conveyers.__index = Conveyers

export type ClassType = typeof(setmetatable({}::{
	_instance:BasePart
},Conveyers))

function Conveyers.new(instance:BasePart)
	local self = {
		_instance = instance,
	}
	setmetatable(self,Conveyers)
	self:init()
	return self
end

function Conveyers.init(self:ClassType)
	self._instance.Anchored = true
	self._instance.CollisionGroup = "WoodBlock"
	self._instance.AssemblyLinearVelocity = -self._instance.CFrame.RightVector * FORCE
end

function Conveyers.destroy(self:ClassType)
	self._instance.AssemblyLinearVelocity = Vector3.zero
end

return Conveyers
