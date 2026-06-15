local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TurnToFacePoint = require(ReplicatedStorage.ReplicatedCode.Framework.Character.BodyOrientation.TurnToFacePoint)

local function followCamera(character: Model, camera: Camera)
	local orientTowards, done = TurnToFacePoint(character)

	RunService:BindToRenderStep("TrackCamera", Enum.RenderPriority.Camera.Value, function()
		orientTowards(camera.CFrame.Position)
	end)

	return function()
		RunService:UnbindFromRenderStep("TrackCamera")
		done()
	end
end

return followCamera

