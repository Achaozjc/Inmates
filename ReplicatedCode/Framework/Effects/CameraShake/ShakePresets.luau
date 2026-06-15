local CameraShake = require(script.Parent)

local ShakePresets  = {}

--local elevatorShake = CameraShake.new()
--elevatorShake.Amplitude = 0.05
--elevatorShake.Frequency = 0.1
--elevatorShake.FadeInTime = 0
--elevatorShake.FadeOutTime = 1

--local explosionShake = CameraShake.new()
--explosionShake.Amplitude = 3
--explosionShake.Frequency = 0.2
--explosionShake.FadeInTime = 0
--explosionShake.FadeOutTime = 2


local lightning = CameraShake.new()
lightning.PositionInfluence = Vector3.new(0.25, 0.25, 0.25)
lightning.RotationInfluence = Vector3.new(4, 1, 1)

--ShakePresets.Explosion = explosionShake
--ShakePresets.Elevator = elevatorShake
ShakePresets.Lightning = lightning


return ShakePresets 
