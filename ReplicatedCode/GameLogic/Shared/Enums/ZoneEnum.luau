--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ZoneKeys = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.ZoneKeys)

local defaultColorSet = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(94, 132, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(96, 214, 177)),
})

local ZoneEnum = {
	[ZoneKeys.Default] = {
		name = "Default Zone",
		color = Color3.fromRGB(94, 132, 255),
		colorSet = defaultColorSet,
	},
} :: { [ZoneKeys.EnumType]: { name: string, color: Color3, colorSet: ColorSequence } }

return ZoneEnum
