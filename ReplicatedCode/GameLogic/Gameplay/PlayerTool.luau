local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local UserService = game:GetService("UserService")
local StarterGui = game:GetService("StarterGui")

local retryAsync = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Common.RetryAsync)

local DATA_STORE_REQUEST_ATTEMPTS = 3
local DATA_STORE_REQUEST_COOLDOWN_CONSTANT = 5
local DATA_STORE_REQUEST_COOLDOWN_EXPONENT = 5


local PlayerTool = {}


function PlayerTool.userOwnsGamePassAsync(player: Player, gamePassID: number): boolean
	local hasPass = false

	local success, message = pcall(function()
		hasPass = MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamePassID)
	end)
	if success then
		return hasPass
	else
		return false
	end
end

function PlayerTool.getNameFromUserId(userId : number)
	local success, result = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	if success then
		return result
	else
		return string.format("<unknown%d>", userId)
	end
end


function PlayerTool.getUserIdFromName(name : string)
	local success, result = pcall(function()
		return Players:GetUserIdFromNameAsync(name)
	end)
	if success then
		return result
	else
		return nil
	end
end


function PlayerTool.getUserInfosByUserIds(ids : {number})
	local success, result = pcall(function()
		return UserService:GetUserInfosByUserIdsAsync(ids)
	end)
	if success then
		return result
	else
		return {}
	end
end


function PlayerTool.getUserThumbnail(id : number, size : Enum.ThumbnailSize? , _type : Enum.ThumbnailType?)
	local content , isReady  = Players:GetUserThumbnailAsync(id , _type or Enum.ThumbnailType.HeadShot , size or Enum.ThumbnailSize.Size420x420)
	return (isReady and content) or ""
end


function PlayerTool.getFirendList(userId : number)
	local success, result = retryAsync(function()	
		return Players:GetFriendsAsync(userId)	
	end, DATA_STORE_REQUEST_ATTEMPTS, DATA_STORE_REQUEST_COOLDOWN_CONSTANT, DATA_STORE_REQUEST_COOLDOWN_EXPONENT)
	if success then
		return result
	else
		return nil
	end
end


return PlayerTool
