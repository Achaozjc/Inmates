local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TurnToFacePoint = require(ReplicatedStorage.ReplicatedCode.Framework.Character.BodyOrientation.TurnToFacePoint)
local LocalCharacter = require(ReplicatedStorage.ReplicatedCode.GameLogic.Modules.LocalCharacter)


local function facePlayer(instance: Model)
	local orientTowards, done = TurnToFacePoint(instance)

	RunService:BindToRenderStep("TrackCamera", Enum.RenderPriority.Camera.Value, function()
		orientTowards(LocalCharacter.rootPart.Position)
	end)

	return function()
		RunService:UnbindFromRenderStep("TrackCamera")
		done()
	end
end

return facePlayer

