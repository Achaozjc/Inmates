--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AttributeEnum = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Enums.AttributeEnum)

local AudioPlayer = {}
AudioPlayer.__index = AudioPlayer

export type ClassType = typeof(setmetatable({} :: {
	audioPlayer: AudioPlayer,
	connection: RBXScriptConnection?
}, AudioPlayer))

function AudioPlayer.new(audioPlayer: AudioPlayer): ClassType
	local self = {
		audioPlayer = audioPlayer,
		connection = nil
	}

	setmetatable(self, AudioPlayer)
	

	self:listen()
	
	self:setup()

	
	return self
end



function AudioPlayer.setup(self: ClassType)

end


function AudioPlayer.listen(self: ClassType)
	self.connection = ReplicatedStorage:GetAttributeChangedSignal(AttributeEnum.Setting.world):Connect(function()
		self.audioPlayer.Volume = (ReplicatedStorage:GetAttribute(AttributeEnum.Setting.world) or 0.5) :: number
	end)
	
	self.audioPlayer.Volume = (ReplicatedStorage:GetAttribute(AttributeEnum.Setting.world) or 0.5) :: number

end


function AudioPlayer.destroy(self: ClassType)
	if self.connection then
		self.connection:Disconnect()
	end
end

return AudioPlayer
