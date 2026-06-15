--!strict

--[[
	Given two attachments and a beam prefab, this class continuously orients duplicates of the attachments
	to face each other so that the beam remains straight.

	Also provides an API to enable/disable the beam and its orientation updates.
--]]

local RunService = game:GetService("RunService")

local BeamBetween = {}
BeamBetween.__index = BeamBetween

export type ClassType = typeof(setmetatable(
	{} :: {
		_attachment1: Attachment,
		_attachment0: Attachment?,
		_beam: Beam,
		_isEnabled: boolean,
		_heartbeatConnection: RBXScriptConnection?,
	},
	BeamBetween
))

function BeamBetween.new(attachment1: Attachment, beamPrefab: Beam): ClassType
	local self = {
		_attachment0 = nil :: Attachment?,
		_attachment1 = attachment1,
		_beam = beamPrefab,
		_isEnabled = false,
		_heartbeatConnection = nil :: RBXScriptConnection?,
	}
	setmetatable(self, BeamBetween)

	BeamBetween._setup(self :: ClassType, attachment1)

	return self :: ClassType
end

function BeamBetween._setup(self: ClassType, attachment1: Attachment)
	self._attachment1.Name = "BeamBetween_" .. attachment1.Name
	self._attachment1.Parent = attachment1.Parent
	self._beam.Attachment1 = self._attachment1
	self._beam.Parent = self._attachment1
end

function BeamBetween._setTarget(self: ClassType, cframe: CFrame)
	self._attachment1.WorldCFrame = cframe
end

function BeamBetween._setupAttach0(self: ClassType, originalAttachment0: Attachment)
	self._attachment0 = originalAttachment0
	self._attachment0.Name = "BeamBetween_" .. originalAttachment0.Name
	self._attachment0.Parent = originalAttachment0.Parent
	self._beam.Attachment0 = self._attachment0
end

function BeamBetween._enable(self: ClassType)
	self._beam.Enabled = true
	self._isEnabled = true

	self._heartbeatConnection = RunService.Heartbeat:Connect(function()
		BeamBetween._update(self)
	end)
end

function BeamBetween._disable(self: ClassType)
	self._beam.Enabled = false
	self._isEnabled = false

	if self._heartbeatConnection then
		self._heartbeatConnection:Disconnect()
	end
end

function BeamBetween.setEnabled(self: ClassType, isEnabled: boolean)
	if isEnabled == self._isEnabled then
		return
	end

	if isEnabled then
		BeamBetween._enable(self)
	else
		BeamBetween._disable(self)
	end
end

function BeamBetween._update(self: ClassType)
	local attachment0 = self._attachment0
	if not attachment0 then
		return
	end
	attachment0.WorldCFrame = CFrame.new(attachment0.WorldPosition, self._attachment1.WorldPosition)
		* CFrame.Angles(0, 0, math.pi / 2)
	self._attachment1.WorldCFrame = CFrame.new(self._attachment1.WorldPosition, attachment0.WorldPosition)
		* CFrame.Angles(0, 0, -math.pi / 2)
end

function BeamBetween.destroy(self: ClassType)
	if self._heartbeatConnection then
		self._heartbeatConnection:Disconnect()
	end

	self._beam:Destroy()
	if self._attachment0 then
		self._attachment0:Destroy()
	end
	self._attachment1:Destroy()
end

return BeamBetween
