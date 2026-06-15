--!strict

--[[
	Manually respawns characters when they die, used because
	Players.CharacterAutoLoads is false so that we can wait to spawn the character
	until their data is fully loaded.
--]]

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local PlayerObjectsContainer = require((ServerStorage :: any).Source.PlayerObjectsContainer) :: any

local CharacterSpawner = {}

function CharacterSpawner.onPlayerAdded(player: Player)
	local characterLoadedWrapper = PlayerObjectsContainer.getCharacterLoadedWrapper(player)
	task.spawn(function()
		while player:IsDescendantOf(Players) do
			player:LoadCharacterAsync()
			characterLoadedWrapper.died:Wait()
		end
	end)
end

return CharacterSpawner
