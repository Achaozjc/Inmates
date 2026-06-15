--!strict

--[[
	Framework 层自有 RemoteFunction 名称枚举。
	仅限 Framework 内部模块使用。
	GameLogic 层的函数名称统一在 GameLogic/SharedConstants/Keys/RemoteFunctionKey.luau 维护。
	新增 Framework 级通用函数时在此处添加，游戏业务函数请勿写入此文件。
--]]

export type EnumType =
  "Change_Settings"
| "Get_Timestamp"

local RemoteFunctionName = {
	Change_Settings = "Change_Settings" :: "Change_Settings",
	Get_Timestamp = "Get_Timestamp" :: "Get_Timestamp",
}

return RemoteFunctionName
