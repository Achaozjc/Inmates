local Debris = game:GetService("Debris")

local FORCE_FIELD_DURATION = 5

local function giveForcefield(character: Model, duration: number?)
	local forceField = Instance.new("ForceField")
	forceField.Visible = true
	forceField.Parent = character

	Debris:AddItem(forceField, duration or FORCE_FIELD_DURATION)
end

return giveForcefield