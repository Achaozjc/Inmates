--!strict

--[[
	Adds a CollectionService tag to all player and character objects.
	Used by CollisionGroupManager to create components wrapped around Characters,
	and by ZoneHandler to check for characters in zones.

	解耦说明：characterLoadedWrapper 由调用方（GameLogic 层）传入，
	TagPlayers 不再直接 require PlayerObjectsContainer，保持 Framework 层纯净。
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local CharacterLoadedWrapper = require(ReplicatedStorage.ReplicatedCode.Framework.Character.CharacterLoadedWrapper)

-- 兼容：SharedConstants.Categories.TagCategory 或扁平结构
local SharedConstants = ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants
local Categories = SharedConstants:FindFirstChild("Categories")
local TagCategory = require(Categories:WaitForChild("TagCategory")) :: any

local TagPlayers = {}
TagPlayers.connections = {} :: { [Player]: any }

function TagPlayers._onCharacterAdded(character: Model)
	CollectionService:AddTag(character, TagCategory.Character)
end

-- characterLoadedWrapper 由外部传入（Main.server.luau 在 onPlayerAdded 中获取后传递）
function TagPlayers.addTags(player: Player, characterLoadedWrapper: CharacterLoadedWrapper.ClassType?)
	CollectionService:AddTag(player, TagCategory.Player)

	if not characterLoadedWrapper then
		return
	end

	if characterLoadedWrapper:isLoaded() then
		TagPlayers._onCharacterAdded(player.Character :: Model)
	end

	TagPlayers.connections[player] = characterLoadedWrapper.loaded:Connect(function(character: any)
		TagPlayers._onCharacterAdded(character :: Model)
	end)
end

function TagPlayers.playerLeave(player: Player)
	if TagPlayers.connections[player] then
		TagPlayers.connections[player]:Disconnect()
		TagPlayers.connections[player] = nil
	end
end

return TagPlayers
