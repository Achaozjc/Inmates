--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Network = require(ReplicatedStorage.ReplicatedCode.Framework.Core.Network)
local RemoteEventKey = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.RemoteEventKey)

local VoteService = {}

local _activeVote = nil
local _votedPlayers: { [number]: number } = {}

function VoteService.start()
	-- Handled by GMActionHandlers.voteStart / voteStop
end

function VoteService.listen()
	Network.connectEvent(RemoteEventKey.VoteSubmit, function(player: Player, optionIndex: number)
		if type(optionIndex) ~= "number" then return end
		if optionIndex ~= 1 and optionIndex ~= 2 then return end

		if _votedPlayers[player.UserId] then
			return -- Already voted
		end

		_votedPlayers[player.UserId] = optionIndex
		
		-- You could broadcast the updated vote counts here if you want to show live results
	end)
end

function VoteService.startVote(data: any)
	_activeVote = data
	table.clear(_votedPlayers)
	Network.fireAllClients(RemoteEventKey.VoteCommand, "start", data)
end

function VoteService.stopVote()
	_activeVote = nil
	table.clear(_votedPlayers)
	Network.fireAllClients(RemoteEventKey.VoteCommand, "stop", nil)
end

function VoteService.getResults()
	if not _activeVote then
		return nil
	end
	
	local opt1Count = 0
	local opt2Count = 0
	
	for _, vote in pairs(_votedPlayers) do
		if vote == 1 then
			opt1Count += 1
		elseif vote == 2 then
			opt2Count += 1
		end
	end
	
	return {
		title = _activeVote.title,
		opt1 = _activeVote.opt1,
		opt2 = _activeVote.opt2,
		opt1Count = opt1Count,
		opt2Count = opt2Count,
		total = opt1Count + opt2Count,
	}
end

return VoteService
