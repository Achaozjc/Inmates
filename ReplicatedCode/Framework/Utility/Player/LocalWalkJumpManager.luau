--!strict

--[[
	A single place to keep track of walk and jump multipliers to avoid conflicts across
	multiple scripts when changing these values
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local ValueManager = require(ReplicatedStorage.ReplicatedCode.Framework.Managers.ValueManager)
local CharacterLoadedWrapper = require(ReplicatedStorage.ReplicatedCode.Framework.Character.CharacterLoadedWrapper)

local localPlayer = Players.LocalPlayer :: Player

local LocalWalkJumpManager = {
	_jumpValueManager = ValueManager.new(StarterPlayer.CharacterJumpHeight),
	_walkValueManager = ValueManager.new(StarterPlayer.CharacterWalkSpeed),
}

function LocalWalkJumpManager._onCharacterAdded(character: Model)
	task.spawn(function()
		local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid

		LocalWalkJumpManager._walkValueManager:setAttachedInstance(humanoid, "WalkSpeed")
		LocalWalkJumpManager._jumpValueManager:setAttachedInstance(humanoid, "JumpHeight")
	end)
end

function LocalWalkJumpManager.getWalkValueManager()
	return LocalWalkJumpManager._walkValueManager
end

function LocalWalkJumpManager.getJumpValueManager()
	return LocalWalkJumpManager._jumpValueManager
end

function LocalWalkJumpManager.setup()
	local characterLoadedWrapper = CharacterLoadedWrapper.new(localPlayer)

	if characterLoadedWrapper:isLoaded() then
		LocalWalkJumpManager._onCharacterAdded(localPlayer.Character :: Model)
	end

	characterLoadedWrapper.loaded:Connect(function(character: any)
		LocalWalkJumpManager._onCharacterAdded(character :: Model)
	end)
end

-- 监听玩家 Attribute，自动为 walkValueManager 添加/移除速度倍率。
-- 由 GameLogic 层在 start 之后调用，Framework 不硬编码任何游戏专属属性名。
function LocalWalkJumpManager.watchWalkAttribute(attributeName: string, multiplier: number)
	localPlayer:GetAttributeChangedSignal(attributeName):Connect(function()
		if localPlayer:GetAttribute(attributeName) then
			LocalWalkJumpManager.getWalkValueManager():setMultiplier(attributeName, multiplier)
		else
			LocalWalkJumpManager.getWalkValueManager():removeMultiplier(attributeName)
		end
	end)
end

return LocalWalkJumpManager

