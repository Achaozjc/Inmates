--!strict

--[[
	Converts KeyCodes into image sprites for ease of creating button hints
	This assumes the sprite sheet is made up of squares of size ICON_SIZE_PIXELS
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local INPUT_SPRITES_ID = 9658715834
local ICON_SIZE_PIXELS = 48

local function getPropertiesAt(xIndex: number, yIndex: number): { ImageRectOffset: Vector2, ImageRectSize: Vector2 }
	assert(xIndex >= 1 and yIndex >= 1, "Index must be a positive integer, starting with 1")

	return {
		ImageRectOffset = Vector2.new((xIndex - 1) * ICON_SIZE_PIXELS, (yIndex - 1) * ICON_SIZE_PIXELS),
		ImageRectSize = Vector2.new(ICON_SIZE_PIXELS, ICON_SIZE_PIXELS),
	}
end

local propertiesByKeyCode: { [Enum.KeyCode]: { ImageRectOffset: Vector2, ImageRectSize: Vector2 } } = {
	[Enum.KeyCode.ButtonA] = getPropertiesAt(1, 1),
	[Enum.KeyCode.ButtonB] = getPropertiesAt(2, 1),
	[Enum.KeyCode.ButtonX] = getPropertiesAt(3, 1),
	[Enum.KeyCode.ButtonY] = getPropertiesAt(4, 1),
}

local function formatImageForKeyCode(imageObject: ImageLabel | ImageButton, keyCode: Enum.KeyCode)
	local properties = propertiesByKeyCode[keyCode]
	--assert(properties, "Missing sprite for key " .. keyCode.Name)

	local imageObjectAny = imageObject :: any

	if properties then
		imageObjectAny.Image = "rbxassetid://" .. tostring(INPUT_SPRITES_ID)
		for property, value in pairs(properties) do
			imageObjectAny[property] = value
		end
	else
		local imageId = UserInputService:GetImageForKeyCode(keyCode :: Enum.KeyCode)
		imageObjectAny.Image = imageId
	end
end

return formatImageForKeyCode
