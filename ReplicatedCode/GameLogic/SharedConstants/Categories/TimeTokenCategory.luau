--主动  1
--被动  2


export type EnumType = 
	"years" 
| "months" 
| "weeks" 
| "days"
| "hours"
| "minutes"
| "seconds"

local TimeTokenCategory = {
	years = 31536000 ::number,  
	months = 2592000 ::number,  
	weeks = 604800 ::number,  
	days = 86400 ::number, 
	hours = 3600 ::number,  
	minutes = 60 ::number, 
	seconds = 1 ::number,  

}

return TimeTokenCategory
