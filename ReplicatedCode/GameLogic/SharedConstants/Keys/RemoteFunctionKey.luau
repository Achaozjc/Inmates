--!strict

export type EnumType = string

local RemoteFunctionKey = {
	ClaimReward = "ClaimReward" :: "ClaimReward",
	Change_Settings = "Change_Settings" :: "Change_Settings",
	Get_Timestamp = "Get_Timestamp" :: "Get_Timestamp",
	RewardedAdEvent = "RewardedAdEvent" :: "RewardedAdEvent",
	-- 排行榜：客户端拉取榜单数据（boardId 可选，缺省返回全部）
	GetLeaderboard = "GetLeaderboard" :: "GetLeaderboard",
	Code_GetReleased = "Code_GetReleased" :: "Code_GetReleased",
	Code_Redeem = "Code_Redeem" :: "Code_Redeem",
	GetEventRewards = "GetEventRewards" :: "GetEventRewards",
}

return RemoteFunctionKey
