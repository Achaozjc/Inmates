--!strict

local PotionManager = {}
PotionManager.__index = PotionManager

export type ClassType = typeof(setmetatable({} :: {
	_player: Player,
}, PotionManager))

function PotionManager.new(player: Player): ClassType
	return setmetatable({
		_player = player,
	}, PotionManager) :: ClassType
end

function PotionManager.start(_self: ClassType)
end

function PotionManager.destroy(_self: ClassType)
end

return PotionManager
