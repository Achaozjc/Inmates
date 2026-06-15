--!strict

--[[
	玩家数据防抖存档：斧头大亨经济字段变更后尽快落盘，避免仅依赖 5 分钟自动存档导致退出丢数。
]]

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataServer = require(ServerScriptService.ServerCode.Framework.DataStore.PlayerData.PlayerDataServer)

local SAVE_DELAY_SECONDS = 2

local DebouncedPlayerSave = {}

local pendingTasks: { [Player]: thread } = {}

function DebouncedPlayerSave.schedule(player: Player)
	if not PlayerDataServer.canSave(player) then
		return
	end

	local existing = pendingTasks[player]
	if existing then
		task.cancel(existing)
	end

	pendingTasks[player] = task.delay(SAVE_DELAY_SECONDS, function()
		pendingTasks[player] = nil
		if player.Parent and PlayerDataServer.canSave(player) then
			PlayerDataServer.saveDataAsync(player)
		end
	end)
end

Players.PlayerRemoving:Connect(function(player: Player)
	local existing = pendingTasks[player]
	if existing then
		task.cancel(existing)
	end
	pendingTasks[player] = nil
end)

return DebouncedPlayerSave
