--主动  1
--被动  2


export type EnumType = 
  "Warn" 
| "Error" 
| "Success" 

local NotifyCategory = {
	Warn = "Warn" :: "Warn",
	Error = "Error" :: "Error",
	Success = "Success" :: "Success",
}

return NotifyCategory
