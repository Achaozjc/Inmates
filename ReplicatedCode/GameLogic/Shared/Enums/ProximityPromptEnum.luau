local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILayerId = require(ReplicatedStorage.ReplicatedCode.Framework.UI.UILayerId)
local UILayerHandler = require(ReplicatedStorage.ReplicatedCode.Framework.UI.UILayerHandler)

return {
	["Leaderboards"] = {
		actionText = "View",
		func = function()
			UILayerHandler.show(UILayerId.GUI_Leaderboard)
		end,
	},

	["Group"] = {
		actionText = "Open",
		func = function()
			UILayerHandler.show(UILayerId.GUI_GroupReward)
		end,
	},

	["Spin"] = {
		actionText = "Open",
		func = function()
			UILayerHandler.show(UILayerId.GUI_Spin)
		end,
	},

	["Update"] = {
		actionText = "Open",
		func = function()
			UILayerHandler.show(UILayerId.GUI_Update)
		end,
	},
}
