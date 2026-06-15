--!strict

local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeatherService = require(ServerScriptService.ServerCode.GameLogic.Service.WeatherService)
local WeatherCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.WeatherCategory)
local OwnerIds = require(ServerScriptService.ServerCode.GameLogic.DataStore.OwnerIds)
local Network = require(ReplicatedStorage.ReplicatedCode.Framework.Core.Network)
local RemoteEventKey = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.RemoteEventKey)

export type Command = {
	PrimaryAlias: string,
	SecondaryAlias: string?,
	PermissionLevel: number, -- 0-255
	Function: (player: Player, args: { string }) -> (),
}

local Commands = {
	Prefix = "/",
	List = {
		--{
		--	PrimaryAlias = "gravity",
		--	SecondaryAlias = "grav",
		--	PermissionLevel = 0,
		--	Function = function(player: Player, args: { string })
		--		local gravity = args[1]
		--		if gravity and tonumber(gravity) then
		--			Workspace.Gravity = tonumber(gravity) :: number
		--		end
		--	end,
		--},
		--{
		--	PrimaryAlias = "walkspeed",
		--	SecondaryAlias = "speed",
		--	PermissionLevel = 0,
		--	Function = function(player: Player, args: { string })
		--		local character = player.Character
		--		if character then
		--			local humanoid = character:FindFirstChildOfClass("Humanoid")
		--			if humanoid then
		--				local speed = args[1]
		--				if speed and tonumber(speed) then
		--					humanoid.WalkSpeed = tonumber(speed) :: number
		--				end
		--			end
		--		end
		--	end,
		--},
		--{
		--	PrimaryAlias = "explode",
		--	SecondaryAlias = nil,
		--	PermissionLevel = 0,
		--	Function = function(player: Player, args: { string })
		--		local character = player.Character
		--		if character then
		--			local primaryPart = character.PrimaryPart
		--			if primaryPart then
		--				local explosion = Instance.new("Explosion")
		--				explosion.Position = primaryPart.Position
		--				explosion.Parent = Workspace
		--			end
		--		end
		--	end,
		--},
		{
			PrimaryAlias = "gm",
			SecondaryAlias = nil,
			PermissionLevel = 0,
			Function = function(player: Player, _args: { string })
				if OwnerIds[player.UserId] == nil then
					return
				end

				Network.fireClient(RemoteEventKey.GMAccessGranted, player, "toggle")
			end,
		},
		{
			PrimaryAlias = "weather",
			SecondaryAlias = nil,
			PermissionLevel = 0,
			Function = function(player: Player, args: { string })
				local weatherName = args[1]
				if weatherName then
					-- 将输入的首字母大写，匹配 WeatherCategory（例如 rain -> Rain）
					local formattedName = weatherName:sub(1,1):upper() .. weatherName:sub(2):lower()
					local category = (WeatherCategory :: any)[formattedName]
					if category then
						WeatherService.applyWeather(category)
					end
				end
			end,
		},
	} :: { Command },
}

return Commands
