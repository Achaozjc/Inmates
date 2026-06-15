--!strict

export type EnumType = string

local RemoteEventKey = {
	Refresh_Timestamp = "Refresh_Timestamp" :: "Refresh_Timestamp",
	Unreliable_ServerChatMessage = "Unreliable_ServerChatMessage" :: "Unreliable_ServerChatMessage",
	Unreliable_ServerNotify = "Unreliable_ServerNotify" :: "Unreliable_ServerNotify",
	Unreliable_GameNotify = "Unreliable_GameNotify" :: "Unreliable_GameNotify",
	ShowCopyCode = "ShowCopyCode" :: "ShowCopyCode",
	PurchasePending = "PurchasePending" :: "PurchasePending",
	SetFavorite = "SetFavorite" :: "SetFavorite",
	FriendLuck = "FriendLuck" :: "FriendLuck",
	VoteCommand = "VoteCommand" :: "VoteCommand",
	VoteSubmit = "VoteSubmit" :: "VoteSubmit",
	GMAccessGranted = "GMAccessGranted" :: "GMAccessGranted",
	GMResult = "GMResult" :: "GMResult",
	GMCommand = "GMCommand" :: "GMCommand",
	GMAuditQuery = "GMAuditQuery" :: "GMAuditQuery",
	GMAuditResult = "GMAuditResult" :: "GMAuditResult",
	AdminEventChanged = "AdminEventChanged" :: "AdminEventChanged",
	AdminEventCommand = "AdminEventCommand" :: "AdminEventCommand",
	GlobalMessage = "GlobalMessage" :: "GlobalMessage",
	GlobalMessageCommand = "GlobalMessageCommand" :: "GlobalMessageCommand",
	-- 斧头大亨：服务端→客户端同步（生产事件/堆叠数量/木料倍率等）
	AxeTycoonSync = "AxeTycoonSync" :: "AxeTycoonSync",
	-- 宝箱：客户端→服务端（捡起/开启/丢弃），及服务端→客户端结果回执
	ChestPickup = "ChestPickup" :: "ChestPickup",
	ChestOpen = "ChestOpen" :: "ChestOpen",
	ChestDiscard = "ChestDiscard" :: "ChestDiscard",
	ChestActionResult = "ChestActionResult" :: "ChestActionResult",
	-- 开箱揭晓：服务端触发 3D 动画，客户端结束后回执落位
	Chest_OpenAnim = "Chest_OpenAnim" :: "Chest_OpenAnim",
	ChestRevealDone = "ChestRevealDone" :: "ChestRevealDone",
	-- 群组奖励：触碰 Group 但未加入群组时，服务端→客户端触发加群弹窗
	GroupRewardPromptJoin = "GroupRewardPromptJoin" :: "GroupRewardPromptJoin",
	-- 离线木料：客户端触碰基地木堆 → 服务端领取（未领取量由 PlayerData.AxeTycoon 同步驱动）
	OfflineWoodClaim = "OfflineWoodClaim" :: "OfflineWoodClaim",
	-- 触碰按钮业务成功后，服务端→客户端触发按钮处粒子特效（参数：按钮名）
	TouchButtonVFX = "TouchButtonVFX" :: "TouchButtonVFX",
	Code_ReleaseUpdate = "Code_ReleaseUpdate" :: "Code_ReleaseUpdate",
	-- 回家：客户端点击 HUD Home 按钮 → 服务端把玩家传送回自己基地出生点
	HomeTeleport = "HomeTeleport" :: "HomeTeleport",
	-- 新手教程：客户端完成某一步后上报（参数：TutorialStepKey），服务端持久化完成标记
	Tutorial_StepComplete = "Tutorial_StepComplete" :: "Tutorial_StepComplete",
}

return RemoteEventKey
