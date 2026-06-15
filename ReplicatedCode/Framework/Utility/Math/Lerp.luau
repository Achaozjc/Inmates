local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

return lerp
