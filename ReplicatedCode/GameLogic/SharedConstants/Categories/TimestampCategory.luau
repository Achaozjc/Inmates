--主动  1
--被动  2


export type EnumType = 
	"min5"
| "min15"
| "hour" 
| "daily" 
| "weekly" 

local TimestampCategory = {
	min5 = "min5" :: "min5",
	min15 = "min15" :: "min15",
	hour = "hour" :: "hour",
	daily = "daily" :: "daily",
	weekly = "weekly" :: "weekly",

}

return TimestampCategory
