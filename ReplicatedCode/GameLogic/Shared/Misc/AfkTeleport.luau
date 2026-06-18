--!strict

--[[
	AFK 传送标记：TeleportManager.afk 写入 TeleportData { afk = true }，落地端读取后做特殊处理。
]]

local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local AfkTeleport = {}

local function readTeleportDataTable(data: any): boolean
	return type(data) == "table" and data.afk == true
end

-- 服务端：玩家本次加入是否来自 AFK 传送
function AfkTeleport.isPlayerReturnJoin(player: Player): boolean
	assert(RunService:IsServer(), "AfkTeleport.isPlayerReturnJoin is server-only")
	local ok, joinData = pcall(function()
		return player:GetJoinData()
	end)
	if not ok or type(joinData) ~= "table" then
		return false
	end
	return readTeleportDataTable(joinData.TeleportData)
end

-- 客户端：本地玩家本次加入是否来自 AFK 传送
function AfkTeleport.isLocalReturnJoin(): boolean
	assert(RunService:IsClient(), "AfkTeleport.isLocalReturnJoin is client-only")
	local ok, data = pcall(TeleportService.GetLocalPlayerTeleportData, TeleportService)
	if not ok then
		return false
	end
	return readTeleportDataTable(data)
end

return AfkTeleport
