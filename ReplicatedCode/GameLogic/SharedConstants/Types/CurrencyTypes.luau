--!strict

--[[
	Types used to enforce in-experience Currencies.
--]]

export type AssetId = number
export type CashKey = string
export type GamePassId = number

export type Currency = {
	displayName: string,
	icon: AssetId?,
	symbol: string?,
}

export type CurrencyList = { [CashKey]: Currency? }

export type PriceType = "Product" | "InExperience" | "GamePass"

export type BasePricing = {
	priceType: PriceType,
}

export type InExperiencePricing = BasePricing & {
	priceType: "InExperience",
	icon: AssetId,
	cashkey: CashKey,
	price: number,
}

export type MarketplacePricing = BasePricing & {
	priceType: "Product",
	productId: AssetId,
	gift: boolean
}

export type GamePassPricing = BasePricing & {
	priceType: "GamePass",
	gamepassId: GamePassId,
	productId: number,
	gift: boolean
 }

export type Pricing = InExperiencePricing | MarketplacePricing | GamePassPricing

local CurrencyTypes = {
	PriceType = {
		Product = "Product" :: "Product",
		InExperience = "InExperience" :: "InExperience",
		GamePass = "GamePass" :: "GamePass",
		Premium = "Premium" :: "Premium",
	},
}

return CurrencyTypes
