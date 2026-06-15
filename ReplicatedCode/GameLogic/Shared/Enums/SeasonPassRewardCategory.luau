--!strict

export type EnumType =
	"Cash"
	| "Item"
	| "Potion"
	| "SpinTicket"
	| "Currency"

local SeasonPassRewardCategory = {
	Cash = "Cash" :: "Cash",
	Item = "Item" :: "Item",
	Potion = "Potion" :: "Potion",
	SpinTicket = "SpinTicket" :: "SpinTicket",
	Currency = "Currency" :: "Currency",
}

return SeasonPassRewardCategory
