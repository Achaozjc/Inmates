--!strict

export type EnumType =
	"Default"
	| "Character"
	| "Water"
	| "Zone"
	| "Weather"
	| "EffectRay"

local CollisionGroup = {
	Default = "Default" :: "Default",
	Character = "Character" :: "Character",
	Water = "Water" :: "Water",
	Zone = "Zone" :: "Zone",
	Weather = "Weather" :: "Weather",
	EffectRay = "EffectRay" :: "EffectRay",
}

return CollisionGroup
