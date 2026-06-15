--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AttributeEnum = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Enums.AttributeEnum)

local SettingEnum = {
	Audio = {
		[AttributeEnum.Setting.bgm] = {
			name = "Music",
			default = 100,
		},
		[AttributeEnum.Setting.sfx] = {
			name = "SFX",
			default = 100,
		},
		[AttributeEnum.Setting.ambient] = {
			name = "Ambient",
			default = 100,
		},
	},

	Display = {
		[AttributeEnum.Setting.lowDetail] = {
			name = "Low Detail",
			default = false,
		},
		[AttributeEnum.Setting.uiScale] = {
			name = "UI Scale",
			default = 100,
		},
	},
}

return SettingEnum
