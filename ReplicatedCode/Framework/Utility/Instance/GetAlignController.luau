--!strict

local AlignOrientation = script.AlignOrientation :: AlignOrientation
local AlignPosition = script.AlignPosition :: AlignPosition


local function getAlignController(basePart: BasePart, center: Attachment, botton: Attachment)

	local alignPosition = AlignPosition:Clone()
	alignPosition.Attachment0 = botton
	alignPosition.Parent = basePart
		
	local alignOrientation = AlignOrientation:Clone()
	alignOrientation.Attachment0 = botton
	alignOrientation.Parent = basePart

	return alignPosition, alignOrientation
end


return getAlignController
