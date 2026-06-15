--!strict

-- Credits to nurokoi
-- Function to create a visual point
local function CreateVisualPoint(): Part
	local part: Part = Instance.new("Part")
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(1,1,1)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Anchored = true
	part.Parent = workspace.Terrain
	--task.delay(0, function() part:Destroy() end)
	return part
end

-- HyperSolver optimized with math.exp for better performance and accuracy
local function hyperSolver(t: number, d: number): number
	local expT: number = math.exp(t)
	local expNegT: number = math.exp(-t)
	local numerator: number = t * (2 * (expT + expNegT - 2) - t * (expT - expNegT))
	local denominator: number = (expT + expNegT - 2) - t * (expT - expNegT) + t * t * d
	return numerator / denominator
end

-- UnitizeDist optimized to reduce computational overhead
local function unitizeDist(dist: number): number
	local catA: number
	if dist < 0.1 then
		catA = (0.23 * dist + 0.1344) * (dist ^ 1.15)
	elseif dist < 0.9 then
		catA = (0.09071 + 0.1462 * dist - 0.1962 * dist^2) * (dist / (1 - dist))
	else
		catA = math.exp(-1.243) * (dist ^ 2) / math.sqrt(1 - dist ^ 2)
	end

	local approxT: number = dist / catA
	local inverseSq: number = 1 / (dist * dist)

	-- Perform 4 iterations of hyperSolver for refinement
	for _ = 1, 4 do
		approxT = hyperSolver(approxT, inverseSq)
	end

	return dist / approxT
end

-- Evaluates the catenary curve using hyperbolic cosine
local function evalCurve(x: number, l: number, a: number): number
	return a * (math.cosh((x - l) / a) - 1)
end

-- Evaluate a point on the RopeConstraint at a given alpha
local function evalPointOnRC(ropeConstraint: RopeConstraint, alpha: number): CFrame
	assert(ropeConstraint.Attachment0 ~= nil and ropeConstraint.Attachment1 ~= nil, "RC Attachments not prepared for " .. tostring(ropeConstraint))

	-- Use type assertions to inform the type checker
	local attachment0 = ropeConstraint.Attachment0 :: Attachment
	local attachment1 = ropeConstraint.Attachment1 :: Attachment

	local A0: CFrame = attachment0.WorldCFrame
	local A1: CFrame = attachment1.WorldCFrame
	local length: number = ropeConstraint.Length

	-- Convert A1 to A0's object space
	local aVec: Vector3 = A0:ToObjectSpace(A1).Position
	local d: number = math.sqrt(aVec.X ^ 2 + aVec.Z ^ 2)
	local h: number = aVec.Y

	local lengthSquared: number = length * length
	local hSquared: number = h * h
	local diff: number = lengthSquared - hSquared

	-- Check if catenary calculation is possible
	if diff <= 0 or d == 0 then
		-- Cannot compute catenary, fall back to linear interpolation
		local pos: Vector3 = A0.Position:Lerp(A1.Position, alpha)
		return CFrame.new(pos)
	end

	local s: number = math.sqrt(diff)
	local ratio: number = d / s

	local catA: number = s * unitizeDist(ratio)

	-- Use math.exp(x) - 1 instead of math.expm1(x)
	local expDOverA: number = math.exp(d / catA) - 1
	local denom: number = h + length

	if denom == 0 or expDOverA == 0 then
		-- Cannot compute xl, fall back to linear interpolation
		local pos: Vector3 = A0.Position:Lerp(A1.Position, alpha)
		return CFrame.new(pos)
	end

	local xl: number = catA * math.log((catA * expDOverA) / denom)
	local ads: number = -evalCurve(0, xl, catA)
	local ade: number = h - evalCurve(d, xl, catA)
	local x: number = d * alpha
	local y: number = evalCurve(x, xl, catA) + ads + (ade - ads) * alpha

	-- Check for invalid numerical results
	if not (x == x and y == y) then -- Checks for NaN
		local pos: Vector3 = A0.Position:Lerp(A1.Position, alpha)
		return CFrame.new(pos)
	end

	local direction: Vector3 = Vector3.new(aVec.X, 0, aVec.Z).Unit
	local trans: Vector3 = Vector3.new(x * direction.X, y, x * direction.Z)
	local resultCFrame: CFrame = A0 * CFrame.new(trans)

	return resultCFrame
end

-- Calculate spacing between points on the rope
local function calculatePointSpacing(ropeConstraint: RopeConstraint, numPoints: number): { [number]: number }
	local result: { [number]: number } = table.create(numPoints)
	local preCFrame: CFrame = evalPointOnRC(ropeConstraint, 0)
	local preP: Vector3 = preCFrame.Position
	local preH: number = preP.Y

	for i = 1, numPoints do
		local alpha: number = i / numPoints
		local currCFrame: CFrame = evalPointOnRC(ropeConstraint, alpha)
		local currPos: Vector3 = currCFrame.Position
		local currH: number = currPos.Y

		local hDiff: number = math.abs(currH - preH)
		local pDiff: Vector3 = currPos - preP
		local la: number = hDiff ^ 2 + pDiff.Magnitude ^ 2

		preH = currH
		preP = currPos
		result[i] = math.sqrt(la)
	end

	return result
end

-- Evaluate points on the RopeConstraint at fixed intervals
local function evalFixedDistPointsOnRC(ropeConstraint: RopeConstraint, intervalDistance: number, resolution: number?): { [number]: CFrame }
	assert(ropeConstraint.Attachment0 ~= nil and ropeConstraint.Attachment1 ~= nil, "RC Attachments not prepared for " .. tostring(ropeConstraint))

	local attachment0 = ropeConstraint.Attachment0 :: Attachment
	local attachment1 = ropeConstraint.Attachment1 :: Attachment

	local A0: Vector3 = attachment0.WorldPosition
	local A1: Vector3 = attachment1.WorldPosition

	local result: { [number]: CFrame } = {}
	local pointRes: number = math.max(resolution or 1000, ropeConstraint.Length / intervalDistance)

	local accu: number = 0
	local lastA: number = 0

	local spacing: { [number]: number } = calculatePointSpacing(ropeConstraint, pointRes)
	for i = 1, #spacing do
		local distance: number = spacing[i]
		accu = accu + distance

		if accu >= intervalDistance then
			local alpha: number = i / pointRes
			local midAlpha: number = (alpha + lastA) / 2
			local cFrame: CFrame = evalPointOnRC(ropeConstraint, midAlpha)
			local trans: Vector3 = cFrame.Position

			if (trans - A0).Magnitude + (trans - A1).Magnitude <= ropeConstraint.Length then
				table.insert(result, cFrame)
			end

			accu = 0
			lastA = alpha
		end
	end

	return result
end

local getRopePointFinder = {}

function getRopePointFinder.Equidistant(attach1 : Attachment, attach2: Attachment, rope: RopeConstraint, distance: number?)
	local A0LocationEquidistant: Vector3 = attach1.WorldPosition
	local A1LocationEquidistant: Vector3 = attach2.WorldPosition
	
	local Now: number = os.clock()

	--local A0Offset: Vector3 = ((Vector3.yAxis * math.sin(Now + 1) ^ 2) + (Vector3.zAxis * math.cos(Now + 2) ^ 2) * 1.5) * 1.5
	--local A1Offset: Vector3 = ((Vector3.yAxis * math.sin(Now + 3) ^ 2) + (Vector3.zAxis * math.cos(Now + 4) ^ 2) * 1.5) * 1.5
	
	--attach1.WorldPosition = A0LocationEquidistant + A0Offset
	--attach2.WorldPosition = A1LocationEquidistant + A1Offset
	
	-- Create visual points for equidistant rope
	local intervalDistance: number = distance or math.max(1, 3 * math.sin(Now * 1.2) ^ 2)

	local points: { [number]: CFrame } = evalFixedDistPointsOnRC(rope, intervalDistance)
	
	--for _, cFrame in ipairs(points) do
	--	local visualPoint: Part = CreateVisualPoint()
	--	visualPoint.CFrame = cFrame	
	--end
	return points
end


function getRopePointFinder.Line(attach1 : Attachment, attach2: Attachment, rope: RopeConstraint, count : number?)
	local A0LocationLinear: Vector3 = attach1.WorldPosition
	local A1LocationLinear: Vector3 = attach2.WorldPosition

	local Now: number = os.clock()

	--local A0Offset: Vector3 = ((Vector3.yAxis * math.sin(Now + 1) ^ 2) + (Vector3.zAxis * math.cos(Now + 2) ^ 2) * 1.5) * 1.5
	--local A1Offset: Vector3 = ((Vector3.yAxis * math.sin(Now + 3) ^ 2) + (Vector3.zAxis * math.cos(Now + 4) ^ 2) * 1.5) * 1.5

	--attach1.WorldPosition = A0LocationLinear + A0Offset
	--attach2.WorldPosition = A1LocationLinear + A1Offset
	
	local points = {}
	
	for i = 1, (count or 4) do		
		local alpha: number = math.sin(Now + i) ^ 2
		local cFrame: CFrame = evalPointOnRC(rope, alpha)
		--local visualPoint: Part = CreateVisualPoint()
		--visualPoint.CFrame = cFrame
		table.insert(points, cFrame)
	end
	
	return points
end

return getRopePointFinder