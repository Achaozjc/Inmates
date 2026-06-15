--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ColorEnum = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Enums.ColorEnum)

export type Buff = {
	type: string,
	zoneKey: string?,
	value: number,
}

export type Entry = {
	key: string,
	displayName: string,
	source: string,
	rarity: number,
	buffs: { Buff },
}

export type VisualStyle = {
	font: Enum.Font,
	color: ColorSequence,
	strokeColor: Color3,
	strokeTransparency: number,
	rotation: number,
}

local ENTRIES: { [string]: Entry } = {}

local TitleConfig = {}

function TitleConfig.getEntry(titleKey: string): Entry?
	return ENTRIES[titleKey]
end

function TitleConfig.getEntries(): { [string]: Entry }
	return ENTRIES
end

function TitleConfig.getVisualStyle(_titleKey: string?, rarity: number?): VisualStyle
	local safeRarity = math.clamp(math.floor(rarity or 3), 1, 8)
	return {
		font = if safeRarity >= 5 then Enum.Font.FredokaOne else Enum.Font.GothamBold,
		color = ColorEnum.RarityColor[safeRarity]
			or ColorSequence.new(ColorEnum.SingleRarityColor[safeRarity] or ColorEnum.colors.White),
		strokeColor = if safeRarity >= 5 then ColorEnum.SingleRarityColor[safeRarity] or ColorEnum.colors.White else ColorEnum.colors.Black,
		strokeTransparency = if safeRarity >= 5 then 0.16 else 0.45,
		rotation = if safeRarity >= 7 then 0 else 10,
	}
end

function TitleConfig.getUnlockConditionText(_titleKey: string): string?
	return nil
end

function TitleConfig.getZoneLuck(_titleKey: string?, _zoneKey: string?): number
	return 0
end

return TitleConfig
