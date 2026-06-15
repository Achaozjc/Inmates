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
		[WeatherCategory.Clear] = "rbxassetid://121839456945469",
		[WeatherCategory.Rain] = "rbxassetid://82146014687847",
		[WeatherCategory.Foggy] = "rbxassetid://84773162064523",
		[WeatherCategory.Windy] = "rbxassetid://73999359152981",
		[WeatherCategory.Snow] = "rbxassetid://118918734655564",
		[WeatherCategory.Thunderstorm] = "rbxassetid://72265738285160",
		[WeatherCategory.Rainbow] = "rbxassetid://117480719337635",
		[WeatherCategory.Tornado] = "rbxassetid://79907163826773",
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
