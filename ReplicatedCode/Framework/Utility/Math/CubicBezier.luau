--!strict

local VECTOR_ZERO = Vector3.zero
local RATE = 3

local function cubicBezier(P0: Vector3, P1: Vector3, P2: Vector3, P3: Vector3, t: number)
	local u = 1 - t
	local tt = t * t
	local uu = u * u
	local uuu = uu * u
	local ttt = tt * t

	local p = VECTOR_ZERO
	p = p + uuu * P0
	p = p + (RATE * uu * t) * P1
	p = p + (RATE * u * tt) * P2
	p = p + ttt * P3
	return p
end


return cubicBezier
