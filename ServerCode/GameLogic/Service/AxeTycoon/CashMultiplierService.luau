--!strict

--[[
	Cash 倍率服务（服务端权威）。

	玩家通过屏幕按钮逐档购买 Cash 倍率（x2 → x4 → x7 → x12 → x20 → x40），
	持久化为 AxeTycoon.cashMultiplierTier（0 表示未购买）。倍率在处理机把库存
	变现为 PendingCash 时生效（ProcessorService 读取 getMultiplier）。

	当前购买档位通过玩家属性 _cashMultiplier 复制到客户端，供屏幕按钮决定
	下一档展示与购买。付费注册见 registerDevProducts。
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ReplicatedCode = ReplicatedStorage:WaitForChild("ReplicatedCode")
local ServerCode = ServerScriptService:WaitForChild("ServerCode")

local safePlayerAdded = require(ReplicatedCode.Framework.Utility.Player.SafePlayerAdded)
local AttributeEnum = require(ReplicatedCode.GameLogic.Shared.Enums.AttributeEnum)
local CashMultiplierConfig = require(ReplicatedCode.GameLogic.Shared.Configs.CashMultiplierConfig)
local PlayerDataKey = require(ReplicatedCode.GameLogic.SharedConstants.Keys.PlayerDataKey)
local PlayerDataServer = require(ServerCode.Framework.DataStore.PlayerData.PlayerDataServer)
local DebouncedPlayerSave = require(ServerCode.GameLogic.Modules.AxeTycoon.DebouncedPlayerSave)

local CashMultiplierService = {}

local started = false

-- 读取玩家当前购买档位（0 表示未购买）
function CashMultiplierService.getTier(player: Player): number
	local axeData = PlayerDataServer.getValue(player, PlayerDataKey.AxeTycoon)
	local tier = if type(axeData) == "table" then axeData.cashMultiplierTier else nil
	return CashMultiplierConfig.clampTier(tier)
end

-- 当前现金倍率（未购买为 1）
function CashMultiplierService.getMultiplier(player: Player): number
	return CashMultiplierConfig.getMultiplier(CashMultiplierService.getTier(player))
end

-- 把当前档位写入玩家属性，供客户端屏幕按钮读取
function CashMultiplierService.syncAttribute(player: Player)
	player:SetAttribute(AttributeEnum.CashMultiplier, CashMultiplierService.getTier(player))
end

-- 授予指定档位（仅升级、不降级）；付费回调据 productKey 反查 index 后调用。
-- 返回是否实际发生了档位提升。
function CashMultiplierService.grantTier(player: Player, tierIndex: number): boolean
	local target = CashMultiplierConfig.clampTier(tierIndex)
	if target <= 0 then
		return false
	end

	local applied = false
	PlayerDataServer.updateValue(player, PlayerDataKey.AxeTycoon, function(data)
		data = if type(data) == "table" then data else {}
		local current = CashMultiplierConfig.clampTier(data.cashMultiplierTier)
		if target > current then
			data.cashMultiplierTier = target
			applied = true
		end
		return data
	end)

	CashMultiplierService.syncAttribute(player)
	if applied then
		DebouncedPlayerSave.schedule(player)
	end
	return applied
end

function CashMultiplierService.start()
	if started then
		return
	end
	started = true

	safePlayerAdded(function(player)
		PlayerDataServer.waitForDataLoadAsync(player)
		CashMultiplierService.syncAttribute(player)
	end)
end

return CashMultiplierService
