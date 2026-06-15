
function checkGuiBounds(guiObject: GuiObject, position: Vector2): boolean
	local pos: Vector2 = guiObject.AbsolutePosition
	local size: Vector2 = guiObject.AbsoluteSize
	return (position.X > pos.X and position.X <= pos.X + size.X and position.Y > pos.Y and position.Y <= pos.Y + size.Y)
end

return checkGuiBounds
