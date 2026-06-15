--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AiAnimate = require(ReplicatedStorage.ReplicatedCode.Framework.Effects.AiAnimate)
local Connections = require(ReplicatedStorage.ReplicatedCode.Framework.Infrastructure.Classes.Connections)

local AiAnimateNpc = {}
AiAnimateNpc.__index = AiAnimateNpc

export type ClassType = typeof(setmetatable({} :: {
	_instance: Model,
	_aiAnimate: AiAnimate.ClassType?,
	_connections: Connections.ClassType,
	_destroyed: boolean,
}, AiAnimateNpc))

-- 同一个 Model 只允许存在一个动画包装，避免重复加载 AnimationTrack。
local activeByModel: { [Model]: ClassType } = setmetatable({}, { __mode = "k" }) :: any

function AiAnimateNpc.new(instance: Instance): ClassType
	local model = instance :: Model
	local existing = activeByModel[model]
	if existing then
		existing:destroy()
	end

	local self = setmetatable({
		_instance = model,
		_aiAnimate = nil,
		_connections = Connections.new(),
		_destroyed = false,
	}, AiAnimateNpc) :: any

	activeByModel[model] = self

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		local ancestryConn = model.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				self:destroy()
			end
		end)
		local destroyingConn = model.Destroying:Connect(function()
			self:destroy()
		end)
		self._connections:add(ancestryConn, destroyingConn)
		return self
	end

	local animateScript = model:FindFirstChild("Animate")
	if animateScript then
		animateScript:Destroy()
	end

	self._aiAnimate = AiAnimate.new(model, nil)
	local ancestryConn = model.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			self:destroy()
		end
	end)
	local destroyingConn = model.Destroying:Connect(function()
		self:destroy()
	end)
	self._connections:add(ancestryConn, destroyingConn)

	return self
end

function AiAnimateNpc.destroy(self: ClassType)
	if self._destroyed then
		return
	end

	self._destroyed = true
	self._connections:disconnect()

	if self._aiAnimate then
		self._aiAnimate:destroy()
		self._aiAnimate = nil
	end

	if activeByModel[self._instance] == self then
		activeByModel[self._instance] = nil
	end
end

return AiAnimateNpc
