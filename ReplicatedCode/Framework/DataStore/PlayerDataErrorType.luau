--!strict


--[[
	伪枚举作为播放器数据错误类型，通过名称进行比较
	而不是比较容易出错的字符串。
--]]

export type EnumType = "DataStoreError" | "SessionLocked"

local PlayerDataErrorType = {
	DataStoreError = "DataStoreError" :: "DataStoreError",
	SessionLocked = "SessionLocked" :: "SessionLocked",
}

return PlayerDataErrorType
