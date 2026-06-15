local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Otter = require(ReplicatedStorage.ReplicatedCode.Framework.Packages.Otter)


local GetBodyAngles = require(ReplicatedStorage.ReplicatedCode.Framework.Character.BodyOrientation.GetBodyAngles)
local DEFAULT_ANGLE =  CFrame.Angles(math.rad(90),math.rad(180),0)

local function turnToFacePoint(character: Model)
	local motor = Otter.createGroupMotor({
		horizontal = 0,
		vertical = 0,
	})
	local neck = character:FindFirstChild("Neck", true) :: Motor6D
	
	motor:onStep(function(values: { horizontal: number, vertical: number })
		if neck then	
			local vertical = values.vertical / 2
			neck.C0 = CFrame.new(neck.C0.Position) * CFrame.Angles(0, values.horizontal, 0)
				* CFrame.Angles(vertical, 0, 0) * DEFAULT_ANGLE	
		end
	end)

	local function orientTowards(point: Vector3)
		local angles = GetBodyAngles(character, point)

		motor:setGoal({
			horizontal = Otter.spring(angles.X),
			vertical = Otter.spring(angles.Y),
		})
	end

	local function done()
		motor:setGoal({
			horizontal = Otter.spring(0),
			vertical = Otter.spring(0),
		})

		motor:onComplete(function()
			motor:destroy()
		end)
	end

	return orientTowards, done
end

return turnToFacePoint


