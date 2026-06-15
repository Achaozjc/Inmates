--!strict

--[[
	通行证配置（端共享）。

	三个一次性永久通行证（Gamepass），购买后永久生效：
		AutoCollectCash 自动收集钱   ：服务端每 AUTO_INTERVAL 秒把 PendingCash 自动领取为 Cash
		AutoCollectWood 自动收集木料 ：服务端每 AUTO_INTERVAL 秒自动背走堆叠区木头并卸入处理机
		DoubleWood      双倍木料     ：玩家入库（Storage 卸料）时木料价值 ×2

	商品 ID 见 StoreIdCategory.Gamepass；购买/授予/自动结算见 GamepassService。
	拥有状态持久化在 PlayerData.Store.gamepass（存通行证 ID），并复制为玩家属性供客户端读取。
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AttributeEnum = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Enums.AttributeEnum)

export type Pass = {
	key: string, -- 对应 StoreIdCategory.Gamepass 中的键
	attribute: string, -- 复制到客户端的拥有状态属性（true=已拥有）
	displayName: string, -- UI 文本（纯英文）
	description: string, -- UI 文本（纯英文）
}

local GamepassConfig = {}

-- 自动收集（钱 / 木料）的结算间隔（秒）
GamepassConfig.AUTO_INTERVAL = 1

-- 双倍木料的入库倍率
GamepassConfig.DOUBLE_WOOD_MULTIPLIER = 2

-- 与商品展示顺序一致
GamepassConfig.Passes = {
	{
		key = "AutoCollectCash",
		attribute = AttributeEnum.GamepassAutoCollectCash,
		displayName = "Auto Collect Cash",
		description = "Automatically collects your pending cash.",
	},
	{
		key = "AutoCollectWood",
		attribute = AttributeEnum.GamepassAutoCollectWood,
		displayName = "Auto Collect Wood",
		description = "Automatically carries wood into your processor.",
	},
	{
		key = "DoubleWood",
		attribute = AttributeEnum.GamepassDoubleWood,
		displayName = "Double Wood",
		description = "Doubles the wood value you deposit.",
	},
} :: { Pass }

-- 按 key 取通行证配置；找不到返回 nil
function GamepassConfig.getByKey(key: string): Pass?
	for _, pass in ipairs(GamepassConfig.Passes) do
		if pass.key == key then
			return pass
		end
	end
	return nil
end

return GamepassConfig
