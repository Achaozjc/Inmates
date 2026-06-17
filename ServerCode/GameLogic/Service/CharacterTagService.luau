--!strict

--[[
	为玩家每次生成的 Character 打上 CollectionService 标签 "Character"，
	供 Binder Character 组件、ZoneHandler 等系统识别。
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Connections = require(ReplicatedStorage.ReplicatedCode.Framework.Infrastructure.Classes.Connections)
local safePlayerAdded = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Player.SafePlayerAdded)
local TagCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.TagCategory)

local CharacterTagService = {}

local connectionsByPlayer: { [Player]: Connections.ClassType } = {}

local function tagCharacter(character: Model)
	CollectionService:AddTag(character, TagCategory.Character)
end

local function onPlayerAdded(player: Player)
	local connections = Connections.new()
	connectionsByPlayer[player] = connections

	connections:add(player.CharacterAdded:Connect(tagCharacter))

	if player.Character then
		tagCharacter(player.Character)
	end
end

local function onPlayerRemoving(player: Player)
	local connections = connectionsByPlayer[player]
	if connections then
		connections:disconnect()
		connectionsByPlayer[player] = nil
	end
end

function CharacterTagService.listen()
	safePlayerAdded(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
end

return CharacterTagService
