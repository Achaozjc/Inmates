local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DescendantsCollisionGroup = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Instance.DescendantsCollisionGroup)

local FORCE = 10

local Character = {}
Character.__index = Character

export type ClassType = typeof(setmetatable({}::{
	_instance:Model,
	_descendantsCollisionGroup:DescendantsCollisionGroup.ClassType,
},Character))

function Character.new(instance:Model)
	local self = {
		_instance = instance,
		_descendantsCollisionGroup = DescendantsCollisionGroup.new(instance,"Character"),
	}
	setmetatable(self,Character)
	self:init()
	return self
end

function Character.init(self:ClassType)
	
end

function Character.destroy(self:ClassType)
	self._descendantsCollisionGroup:destroy()
end

return Character
