--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Connections = require(ReplicatedStorage.ReplicatedCode.Framework.Infrastructure.Classes.Connections)

local GUIScale = {}
GUIScale.__index = GUIScale

export type ClassType = typeof(setmetatable(
	{} :: {
		_instance: any,
		_connections: Connections.ClassType,
		_factor: number,
	},
	GUIScale
))

function GUIScale.new(instance: GuiObject): ClassType
	local self = {
		_instance = instance,
		_connections = Connections.new(),
		_factor = (instance:GetAttribute("Factor") or nil) :: number,
	}

	setmetatable(self, GUIScale)

	self:setup()

	self:listen()

	return self
end

function GUIScale.setup(self: ClassType)
	self:scale()
end

function GUIScale.scale(self: ClassType) end

function GUIScale.listen(self: ClassType)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local listen = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		self:scale()
	end)
	self._connections:add(listen)
end

function GUIScale.destroy(self: ClassType)
	self._connections:disconnect()
end

return GUIScale
