
local function cframeFromMatrix(cframe: CFrame)
	return CFrame.fromMatrix(
		cframe.Position,
		cframe.XVector,
		cframe.YVector,
		-cframe.ZVector
	)
end


return cframeFromMatrix
