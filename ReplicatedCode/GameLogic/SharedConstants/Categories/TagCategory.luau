--!strict

export type EnumType =
	"Player"
	| "Character"
	| "UI_Scale"
	| "BuildAnim"
	| "Nightlight"
	| "LeaderboardScreen"
	| "ProximityAttach"
	| "ZoneHandler"
	| "Zone"
	| "AiAnimateNpc"
	| "ChestTool"
	| "CodeBoard"

local TagCategory = {
	Player = "Player" :: "Player",
	Character = "Character" :: "Character",
	UI_Scale = "UI_Scale" :: "UI_Scale",
	BuildAnim = "BuildAnim" :: "BuildAnim",
	Nightlight = "Nightlight" :: "Nightlight",
	LeaderboardScreen = "LeaderboardScreen" :: "LeaderboardScreen",
	ProximityAttach = "ProximityAttach" :: "ProximityAttach",
	ZoneHandler = "ZoneHandler" :: "ZoneHandler",
	Zone = "Zone" :: "Zone",
	AiAnimateNpc = "AiAnimateNpc" :: "AiAnimateNpc",
	ChestTool = "ChestTool" :: "ChestTool",
	CodeBoard = "CodeBoard" :: "CodeBoard",
}

return TagCategory
