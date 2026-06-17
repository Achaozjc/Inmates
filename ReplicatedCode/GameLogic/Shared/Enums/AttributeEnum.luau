--!strict

export type EnumType = string

local AttributeEnum = {
	OriginalCollisionGroup = "OriginalCollisionGroup" :: "OriginalCollisionGroup",
	Teleproting = "Teleproting" :: "Teleproting",
	UILoaded = "UILoaded" :: "UILoaded",
	InElevator = "InElevator" :: "InElevator",
	GMAccessGranted = "_gmAccessGranted" :: "_gmAccessGranted",

	Speed = "_speed" :: "_speed",
	OwnerId = "_ownerId" :: "_ownerId",
	Uid = "_uid" :: "_uid",
	Sit = "_sit" :: "_sit",
	ZoneKey = "_zoneKey" :: "_zoneKey",
	FriendLuck = "_friendLuck" :: "_friendLuck", -- 好友同服 Cash 加成倍率（1=无加成，上限 1.5）
	IsLock = "_isLock" :: "_isLock",
	TypeSize = "_typeSize" :: "_typeSize",
	Luck = "_luck" :: "_luck",
	Flipped = "_flipped" :: "_flipped",
	ToolClass = "_toolClass" :: "_toolClass",
	Charge = "_charge" :: "_charge",
	Rarity = "_rarity" :: "_rarity",

	Lv = "_lv" :: "_lv",
	Count = "_count" :: "_count",
	Size = "_size" :: "_size",
	Scale = "_scale" :: "_scale",
	Category = "_category" :: "_category",
	Key = "_key" :: "_key",
	TypeCategory = "_typeCategory" :: "_typeCategory",
	Feature = "_feature" :: "_feature",
	PlaceId = "_placeId" :: "_placeId",
	Enabled = "_enabled" :: "_enabled",
	OriginalCFrame = "_originalCFrame" :: "_originalCFrame",
	Shake = "_shake" :: "_shake",
	Auto = "_auto" :: "_auto",
	Oxygen = "_oxygen" :: "_oxygen",
	OxygenMax = "_oxygenMax" :: "_oxygenMax",
	CurrentWeather = "_currentWeather" :: "_currentWeather",
	ActiveDevActivity = "ActiveDevActivity" :: "ActiveDevActivity",
	Clock = "_clock" :: "_clock",
	ClockTime = "_clockTime" :: "_clockTime",
	DayNight = "_dayNight" :: "_dayNight",
	StudioForceClockTime = "_studioForceClockTime" :: "_studioForceClockTime",
	ExpBonus = "_expBonus" :: "_expBonus",
	ServerLuckLv = "_serverLuckLv" :: "_serverLuckLv",
	ServerLuckLeftTime = "_serverLuckLeftTime" :: "_serverLuckLeftTime",
	PlayerServerLuckLv = "_playerServerLuckLv" :: "_playerServerLuckLv",
	PlayerServerLuckLeftTime = "_playerServerLuckLeftTime" :: "_playerServerLuckLeftTime",
	Destruction = "_destruction" :: "_destruction",
	-- Cash 倍率当前购买档位（0=未购买，1..MaxTier），复制到客户端供屏幕按钮读取
	CashMultiplier = "_cashMultiplier" :: "_cashMultiplier",

	-- 通行证拥有状态（true=已拥有），复制到客户端供 UI 读取，授予见 GamepassService
	GamepassAutoCollectCash = "_gpAutoCollectCash" :: "_gpAutoCollectCash",
	GamepassAutoCollectWood = "_gpAutoCollectWood" :: "_gpAutoCollectWood",
	GamepassDoubleWood = "_gpDoubleWood" :: "_gpDoubleWood",

	-- 群组奖励下次可领取的 Unix 时间戳（0=可立即领取），复制到客户端供 Billboard 倒计时
	GroupRewardReadyAt = "_groupRewardReadyAt" :: "_groupRewardReadyAt",

	-- 处理机状态（写在 Base_* 折叠上，复制给所有客户端渲染 CashWall 墙面）
	ProcessorStock = "_processorStock" :: "_processorStock",
	ProcessorUpgradeCount = "_processorUpgradeCount" :: "_processorUpgradeCount",

	Player = {
		lv = "Lv" :: string,
		tagId = "tagId" :: string,
		vip = "vip" :: string,
	},

	Setting = {
		bgm = "s_bgm",
		sfx = "s_sfx",
		ambient = "s_ambient",
		world = "s_world",
		cameraShake = "s_cameraShake",
		gamepadVibration = "s_gamepadVibration",
		serverNotify = "s_serverNotify",
		globalNotify = "s_globalNotify",
		lowDetail = "s_lowDetail",
		showPlayerPosition = "s_showPlayerPosition",
		uiScale = "s_uiScale",
	},
}

return AttributeEnum
