--!strict

export type EnumType = Enum.AnalyticsEconomyTransactionType

local TransactionEnum = {
	Gameplay = Enum.AnalyticsEconomyTransactionType.Gameplay.Name , -- 通过游戏赚取或支付的货币，例如赢得比赛所获得的经验"金币"。
	IAP = Enum.AnalyticsEconomyTransactionType.IAP.Name , -- 表示通过 Robux 购买的货币来源，例如用 Robux 购买的体验"黄金"。
	Shop = Enum.AnalyticsEconomyTransactionType.Shop.Name , -- 在商店内购买，例如使用体验中的"硬币"来购买体验中的物品。
	TimedReward = Enum.AnalyticsEconomyTransactionType.TimedReward.Name , -- 基于时间的奖励，例如每天登录可获得经验"金币"。
	Onboarding = Enum.AnalyticsEconomyTransactionType.Onboarding.Name , -- 与入职相关的交易，例如完成教程后奖励的体验"金币"。
	ContextualPurchase = Enum.AnalyticsEconomyTransactionType.ContextualPurchase.Name , -- 与奖励直接相关的购买，例如用于购买额外生命的经验"黄金"。
	ForeverPack = "ForeverPack" :: "ForeverPack",
	Code = "Code" :: "Code",
} 

return TransactionEnum 
