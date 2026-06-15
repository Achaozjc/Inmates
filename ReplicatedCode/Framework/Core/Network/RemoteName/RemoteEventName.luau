--!strict

--[[
	Framework 层自有 RemoteEvent 名称枚举。
	仅限 Framework 内部模块（PlayerDataServer、TeleportManager 等）使用。
	GameLogic 层的事件名称统一在 GameLogic/SharedConstants/Keys/RemoteEventKey.luau 维护。
	新增 Framework 级通用事件时在此处添加，游戏业务事件请勿写入此文件。
--]]

export type EnumType =
  "PlayerDataLoaded"
| "PlayerDataUpdated"
| "PlayerDataSaved"
| "PlayerDataLoadedError"
| "ResetData"

| "PurchasePending"

| "Unreliable_ServerNotify"
| "Unreliable_ServerChatMessage"
| "Unreliable_Transitions"

| "Teleport_Time"
| "Teleport_Gui"
| "Teleport_Select"

| "Refresh_Timestamp"

| "ExplosionHit"

local RemoteEventName = {
	PlayerDataLoaded = "PlayerDataLoaded" :: "PlayerDataLoaded",
	PlayerDataUpdated = "PlayerDataUpdated" :: "PlayerDataUpdated",
	PlayerDataSaved = "PlayerDataSaved" :: "PlayerDataSaved",
	PlayerDataLoadedError = "PlayerDataLoadedError" :: "PlayerDataLoadedError",
	ResetData = "ResetData" :: "ResetData",

	PurchasePending = "PurchasePending" :: "PurchasePending",

	Unreliable_ServerNotify = "Unreliable_ServerNotify" :: "Unreliable_ServerNotify",
	Unreliable_ServerChatMessage = "Unreliable_ServerChatMessage" :: "Unreliable_ServerChatMessage",
	Unreliable_Transitions = "Unreliable_Transitions" :: "Unreliable_Transitions",

	Teleport_Time = "Teleport_Time" :: "Teleport_Time",
	Teleport_Gui = "Teleport_Gui" :: "Teleport_Gui",
	Teleport_Select = "Teleport_Select" :: "Teleport_Select",

	Refresh_Timestamp = "Refresh_Timestamp" :: "Refresh_Timestamp",

	ExplosionHit = "ExplosionHit" :: "ExplosionHit",
}

return RemoteEventName
