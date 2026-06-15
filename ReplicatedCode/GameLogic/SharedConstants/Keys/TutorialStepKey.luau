--!strict

--[[
	新手教程步骤键（端共享）。

	客户端按顺序引导，每步完成后经 Tutorial_StepComplete 上报；
	服务端将对应标记写入 PlayerData.Tutorial.newbie（见 TutorialService / TutorialController）。
]]

export type EnumType = string

local TutorialStepKey = {
	BuyAxe = "BuyAxe" :: "BuyAxe", -- 购买第一把斧子
	CollectWood = "CollectWood" :: "CollectWood", -- 收集一次木头（有自动收集木头通行证则跳过）
	DepositWood = "DepositWood" :: "DepositWood", -- 将木头放入处理机
	CollectCash = "CollectCash" :: "CollectCash", -- 收集一次 Cash（有自动收集 Cash 通行证则跳过）
	UpgradeProcessor = "UpgradeProcessor" :: "UpgradeProcessor", -- 升级一次处理机
}

return TutorialStepKey
