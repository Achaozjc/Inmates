--!strict

export type EnumType =
	"purchaseSuccess"
	| "upVoteUpdate"
	| "feature"
	| "redPoint"
	| "gamepassPurchase"
	| "notify"
	| "dialogue"
	| "gift"
	| "newbie_event"
	| "newbie_step"
	| "teleport"
	| "openGui"
	| "gameNotify"

local TriggerSignalCategory = {
	Event = {
		purchaseSuccess = "purchaseSuccess" :: "purchaseSuccess",
		upVoteUpdate = "upVoteUpdate" :: "upVoteUpdate",
		feature = "feature" :: "feature",
	},

	Client = {
		redPoint = "redPoint" :: "redPoint",
		gamepassPurchase = "gamepassPurchase" :: "gamepassPurchase",
		notify = "notify" :: "notify",
		dialogue = "dialogue" :: "dialogue",
		gift = "gift" :: "gift",
		newbie_event = "newbie_event" :: "newbie_event",
		newbie_step = "newbie_step" :: "newbie_step",
		teleport = "teleport" :: "teleport",
		openGui = "openGui" :: "openGui",
		gameNotify = "gameNotify" :: "gameNotify",
	},
}

return TriggerSignalCategory
