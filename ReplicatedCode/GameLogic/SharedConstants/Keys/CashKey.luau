--[[
	Keys used by the PlayerData system
--]]

export type EnumType = "Cash" | "PendingCash" 

local CashKey = {
	Cash        = "Cash"        :: "Cash",	
	PendingCash = "PendingCash" :: "PendingCash",
}

return CashKey
