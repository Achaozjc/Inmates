--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CashKey = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.CashKey)
local WeatherCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.WeatherCategory)
local ItemKeyCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.ItemKeyCategory)
local DayNightCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.DayNightCategory)

export type EnumType = string

local IconCategory = {
	Currency = {
		[CashKey.Cash] = "rbxassetid://76322961351433",
	} :: { [CashKey.EnumType]: string },

	TypeIcon = {} :: { [string]: string },

	DayNight = {
		[DayNightCategory.Day] = "rbxassetid://79661543902569",
		[DayNightCategory.Night] = "rbxassetid://91574103433183",
	} :: { [DayNightCategory.EnumType]: string },

	Weather = {
		[WeatherCategory.Sunny] = "rbxassetid://119531317629257",
		[WeatherCategory.Rain] = "rbxassetid://81925884515883",
		[WeatherCategory.Fog] = "rbxassetid://82502243391145",
		[WeatherCategory.Snow] = "rbxassetid://130574613275771",
		[WeatherCategory.Thunderstorm] = "rbxassetid://136579182930227",
	} :: { [WeatherCategory.EnumType]: string },

	Items = {
		[ItemKeyCategory.cash] = "rbxassetid://118389833451936",
		[ItemKeyCategory.luck1] = "rbxassetid://136390485608548",
		[ItemKeyCategory.luck2] = "rbxassetid://111145311075817",
		[ItemKeyCategory.moveSpeed] = "rbxassetid://84375625052123",
		[ItemKeyCategory.autoCollect] = "rbxassetid://86817539783913",
		[ItemKeyCategory.serverLuck] = "rbxassetid://104322420847336",
		[ItemKeyCategory.SpinTicket] = "rbxassetid://120336629535410",
		[ItemKeyCategory.enchant1] = "rbxassetid://91766945523760",
		[ItemKeyCategory.enchant2] = "rbxassetid://102351094308383",
	} :: { [string]: string },
} :: { [string]: any }

return IconCategory
