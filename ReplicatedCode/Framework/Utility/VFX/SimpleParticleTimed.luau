--[[
	simpleParticleTimed - A utility function to spawn a part with particles in it for a limited time,
	waiting for those particles to fade out at the end before destroying it.
--]]

local Workspace = game:GetService("Workspace")

-- Play a particle effect for a specific amount of time, allowing extra time for the particles to fade at the end
local function simpleParticleTimed(effectTemplate: BasePart, cframe: CFrame, lifetime: number, attachTo: BasePart?)
	local effect = effectTemplate:Clone()
	effect.CFrame = if attachTo then attachTo.CFrame * cframe else cframe
	effect.Parent = Workspace

	if attachTo then
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = attachTo
		weld.Part1 = effect
		weld.Parent = effect
	end

	local particleEmitters = {}
	local particleLifetime = 0

	-- Find all the particle emitters and get the maximum lifetime for them
	for _, v in effect:GetDescendants() do
		if not v:IsA("ParticleEmitter") then
			continue
		end

		table.insert(particleEmitters, v)
		particleLifetime = math.max(particleLifetime, v.Lifetime.Max)
	end

	task.delay(lifetime, function()
		-- Disable all the particle emitters
		for _, emitter in particleEmitters do
			emitter.Enabled = false
		end

		-- Wait for them to fade before destroying the effect
		task.delay(particleLifetime, function()
			effect:Destroy()
		end)
	end)
end

return simpleParticleTimed
