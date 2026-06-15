--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Janitor = require(ReplicatedStorage.ReplicatedCode.Framework.Packages.Janitor)

local ProximityPromptEnum = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Enums.ProximityPromptEnum)


local ProximityAttach = {}
ProximityAttach.__index = ProximityAttach

export type ClassType = typeof(setmetatable({} :: {
	_attach: Attachment,
	_janitor: Janitor.Janitor,
	_proximity : ProximityPrompt,
	_info: any

}, ProximityAttach))

function ProximityAttach.new(attach: Attachment): ClassType
	local self = {
		_attach = attach,
		_janitor = Janitor.new(),
		_proximity = Instance.new("ProximityPrompt"),
	
	}

	setmetatable(self, ProximityAttach)
	
	self._info = ProximityPromptEnum[attach.Name] 
	
	self:setup()
	self:listen()

	return self
end

function ProximityAttach.setup(self: ClassType)
	
	
	self._proximity.ActionText = self._info.actionText
	self._proximity.HoldDuration = 0
	self._proximity.MaxActivationDistance = (self._attach:GetAttribute("MaxActivationDistance") or 10) :: number
	self._proximity.MaxIndicatorDistance = (self._attach:GetAttribute("MaxIndicatorDistance") or 50) :: number--self._proximity.MaxActivationDistance + 10
	--self._proximity.RequiresLineOfSight = false
	self._proximity.ObjectText = self._info.objectText or ""
	self._proximity.Style = Enum.ProximityPromptStyle.Custom
	self._proximity.Parent = self._attach	
end



function ProximityAttach.listen(self: ClassType)
	local func = self._info.func
	
	self._janitor:Add(self._proximity.Triggered:Connect(function()
		if func then
			func()
		end
	end),"Disconnect") 
	
end


function ProximityAttach.destroy(self: ClassType)
	self._janitor:Destroy()
end

return ProximityAttach

