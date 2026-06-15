--!strict
-- 群组 ID：该群组内玩家按当前排名作为权限等级
-- UserIds：按 UserId 覆盖的权限等级，优先于 GroupId

local Admins = {
	GroupId = -1,
	UserIds = {
		[game.CreatorId] = 255,
	},
}

return Admins
