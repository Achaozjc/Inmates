

function alignmentPlace(instance :Model | Tool, part :BasePart)
	local modelSize = instance:GetExtentsSize()
	local orignal = part:GetPivot()
	local offset = orignal.Position + Vector3.new(0, modelSize.Y / 2, 0)
	local newCFrame = CFrame.new(offset, offset + orignal.LookVector)
	instance:PivotTo(newCFrame)
end

return alignmentPlace
