--!strict

export type EnumType =
	"Bundle"
	| "Gamepass"
	| "Cash"
	| "Feature"
	| "ForeverPack"
	| "Pack"
	| "Booster"
	| "ServerLuck"
	| "Spin"
	| "SeasonPass"
	| "RewardedVideo"

local StoreCategory = {
	Bundle = "Bundle" :: "Bundle",
	Gamepass = "Gamepass" :: "Gamepass",
	Cash = "Cash" :: "Cash",
	Feature = "Feature" :: "Feature",
	ForeverPack = "ForeverPack" :: "ForeverPack",
	Pack = "Pack" :: "Pack",
	Booster = "Booster" :: "Booster",
	ServerLuck = "ServerLuck" :: "ServerLuck",
	Spin = "Spin" :: "Spin",
	SeasonPass = "SeasonPass" :: "SeasonPass",
	RewardedVideo = "RewardedVideo" :: "RewardedVideo",
}

return StoreCategory
