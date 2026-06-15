--!strict
-- 世界环境音盒子 Binder 组件（客户端）
-- 标签：SpatialSoundPartClient
-- 功能：自动播放挂载在 BasePart 上的循环 AudioPlayer（3D 空间环境音），
--        并通过 AudioPlayer 组件响应 s_world 音量设置

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AudioPlayerWrapper = require(ReplicatedStorage.ReplicatedCode.GameLogic.Components.Common.Other.AudioPlayer)

local SpatialSoundPartClient = {}
SpatialSoundPartClient.__index = SpatialSoundPartClient

export type ClassType = typeof(setmetatable({} :: {
	_part: BasePart,
	_wrappers: { AudioPlayerWrapper.ClassType },
	_players: { AudioPlayer },
}, SpatialSoundPartClient))

function SpatialSoundPartClient.new(instance: Instance): ClassType
	local self = setmetatable({
		_part = instance :: BasePart,
		_wrappers = {},
		_players = {},
	}, SpatialSoundPartClient)

	self:_setup()
	return self
end

function SpatialSoundPartClient._setup(self: ClassType)
	for _, child in self._part:GetChildren() do
		if not child:IsA("AudioPlayer") then
			continue
		end
		local player = child :: AudioPlayer
		table.insert(self._wrappers, AudioPlayerWrapper.new(player))
		table.insert(self._players, player)
		player:Play()
	end
end

function SpatialSoundPartClient.destroy(self: ClassType)
	for _, player in self._players do
		player:Stop()
	end
	for _, wrapper in self._wrappers do
		wrapper:destroy()
	end
	table.clear(self._players)
	table.clear(self._wrappers)
end

return SpatialSoundPartClient
