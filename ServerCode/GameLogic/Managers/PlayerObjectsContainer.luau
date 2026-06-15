--!strict

--[[
	纯注册表：存储与玩家生命周期绑定的对象。
	不负责创建——对象由 Main.server.luau 构造后通过 register() 注入，
	从而彻底切断本模块与具体业务类之间的 require 依赖，避免循环引用。
--]]

-- CharacterLoadedWrapper / PotionManager 等具体类型仅在此做类型引用，
-- 运行时不产生 require 调用（Luau typeof 推导不触发循环）。
type _HasDestroy = { destroy: (self: any) -> () }

type PlayerObjects = {
	characterLoadedWrapper: _HasDestroy,
	potionManager: _HasDestroy,
	[string]: _HasDestroy,
}

local PlayerObjectsContainer = {}
PlayerObjectsContainer._objectsByPlayer = {} :: { [Player]: PlayerObjects }

-- 由 Main.server.luau 在玩家数据加载后调用，传入已构造好的对象表
function PlayerObjectsContainer.register(player: Player, objects: PlayerObjects)
	PlayerObjectsContainer._objectsByPlayer[player] = objects
end

function PlayerObjectsContainer.unregisterPlayer(player: Player)
	local playerObjects = PlayerObjectsContainer._objectsByPlayer[player]

	if playerObjects then
		for _, object in pairs(playerObjects) do
			object:destroy()
		end
	end
	PlayerObjectsContainer._objectsByPlayer[player] = nil
end

--function PlayerObjectsContainer.getCharacterWrapper(player: Player)
--	return PlayerObjectsContainer._objectsByPlayer[player] and PlayerObjectsContainer._objectsByPlayer[player].characterWrapper or nil
--end

function PlayerObjectsContainer.getCharacterLoadedWrapper(player: Player)
	local objects = PlayerObjectsContainer._objectsByPlayer[player]
	return objects and objects.characterLoadedWrapper or nil
end

function PlayerObjectsContainer.getPotionManager(player: Player)
	local objects = PlayerObjectsContainer._objectsByPlayer[player]
	return objects and objects.potionManager or nil
end

return PlayerObjectsContainer
