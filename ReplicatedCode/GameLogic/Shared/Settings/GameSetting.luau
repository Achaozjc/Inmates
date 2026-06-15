--!strict

local GameSetting = {
	DATA_STORE_NAME = "framework-player-data",
	DATA_STORE_VERSION = "v1",
	-- 排行榜 OrderedDataStore 版本（与玩家数据版本独立，便于单独清空榜单）
	ORDER_DATA_STORE_VERSION = "v1",
	-- 排行榜刷新间隔（秒）：服务端写入在线玩家分值并读回 Top100 的周期
	LEADERBOARD_UPDATE_INTERVAL = 120,
	CODE_DATA_NAME = "framework-code-data",
	DATA_STORE_REQUEST_ATTEMPTS = 3,
	DATA_STORE_REQUEST_COOLDOWN_CONSTANT = 2,
	DATA_STORE_REQUEST_COOLDOWN_EXPONENT = 2,
	AUTOSAVE_INTERVAL = 300,
}

return GameSetting
