--!strict

--[[
	Tracks a model's location based on its primary part, checking if it's within a zone.
	Adds tags to the model depending on which zones it is in.

	This class assumes zones are static and that these ZoneParts exist when the class is constructed.

	Each ZonePart should also have a string attribute, Attribute.ZoneId, containing the name of the zone
	corresponding with a ZoneTag.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local AttributeEnum = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Enums.AttributeEnum)
local ZoneKeys = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.ZoneKeys)
local CollisionGroup = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Misc.CollisionGroup)

local CHECK_INTERVAL = 0.5

local setInterval = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Time.SetInterval)

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Include
overlapParams.FilterDescendantsInstances = CollectionService:GetTagged("Zone")
overlapParams.CollisionGroup = CollisionGroup.Character
overlapParams.MaxParts = 8

local offset = Vector3.yAxis * -2
local MOVE_THRESHOLD = 1
local MOVE_THRESHOLD_SQ = MOVE_THRESHOLD * MOVE_THRESHOLD


local ZoneHandler = {}
ZoneHandler.__index = ZoneHandler

export type ClassType = typeof(setmetatable(
	{} :: {
	
		_clearInterval: (() -> nil)?,
		_destroyed: boolean,
		_lastCheckPosition: Vector3?,
		_player: Player,
		_primaryPart: BasePart,
		_zoneKey: string
	},
	ZoneHandler
))

function ZoneHandler.new(player: Player, primaryPart: BasePart): ClassType
	local self = {
		_clearInterval = nil,
		_destroyed = false,
		_lastCheckPosition = nil,
		_zoneKey = "",
	}

	setmetatable(self, ZoneHandler)
	
	self._player = player
	self._primaryPart = primaryPart ::BasePart
	
	self:_watchForZoneChange()

	return self
end



function ZoneHandler._updateZoneTags(self: ClassType)
	local currentPosition = self._primaryPart.Position
	local lastCheckPosition = self._lastCheckPosition
	if lastCheckPosition and self._zoneKey ~= "" then
		local delta = currentPosition - lastCheckPosition
		if delta:Dot(delta) < MOVE_THRESHOLD_SQ then
			return
		end
	end

	self._lastCheckPosition = currentPosition

	local zoneKey : ZoneKeys.EnumType
	local touchParts = Workspace:GetPartBoundsInRadius(self._primaryPart.Position + offset, 4 , overlapParams)
	for _, touchPart in ipairs(touchParts) do
		zoneKey = ZoneKeys[touchPart.Name]
		if zoneKey then
			break
		end
	end
	
	if self._zoneKey == zoneKey then
		return
	end
	
	self._zoneKey = zoneKey
	
	self._player:SetAttribute(AttributeEnum.ZoneKey, zoneKey or ZoneKeys.Default)
	
end

function ZoneHandler._watchForZoneChange(self: ClassType)
	self._clearInterval = setInterval(function()
		self:_updateZoneTags()
	end, CHECK_INTERVAL)
end

function ZoneHandler.destroy(self: ClassType)
	self._destroyed = true

	if self._clearInterval then
		self._clearInterval()
	end
end

return ZoneHandler
