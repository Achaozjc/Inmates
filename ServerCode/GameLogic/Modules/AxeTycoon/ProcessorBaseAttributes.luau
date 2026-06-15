--!strict

--[[
	处理机基地属性同步（服务端写、全客户端读）。

	将玩家 AxeTycoon 数据中的 processorStock / processorUpgradeCount 写到其基地折叠的
	Attribute 上，借助 Roblox 属性复制让所有客户端都能渲染 CashWall 墙面文本
	（渲染逻辑见客户端 CashWallController）。

	写入时机：基地分配（初始值）、Storage 卸货、每秒结算、付费秒处理、处理机升级；
	基地回收时清除，墙面回落为默认显示。
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AttributeEnum = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Enums.AttributeEnum)

local ProcessorBaseAttributes = {}

-- 从 AxeTycoon 数据表读取处理机状态并写到基地 Attribute；data 非表时写入 0
function ProcessorBaseAttributes.apply(base: Instance, axeData: any)
	local stock = 0
	local upgradeCount = 0
	if type(axeData) == "table" then
		stock = tonumber(axeData.processorStock) or 0
		upgradeCount = tonumber(axeData.processorUpgradeCount) or 0
	end
	base:SetAttribute(AttributeEnum.ProcessorStock, stock)
	base:SetAttribute(AttributeEnum.ProcessorUpgradeCount, upgradeCount)
end

-- 基地回收时清除处理机属性
function ProcessorBaseAttributes.clear(base: Instance)
	base:SetAttribute(AttributeEnum.ProcessorStock, nil)
	base:SetAttribute(AttributeEnum.ProcessorUpgradeCount, nil)
end

return ProcessorBaseAttributes
