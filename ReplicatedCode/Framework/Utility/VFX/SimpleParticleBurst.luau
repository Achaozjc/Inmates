--[[
	simpleParticleBurst - A utility function to spawn a part and emit particles from it,
	destroying it after they have faded away.

	The amount of particles per emitter is determined by an attribute on each emitter: "emitAmount"
--]]

local Workspace = game:GetService("Workspace")

local EMIT_AMOUNT_ATTRIBUTE = "emitAmount"

-- Play a single burst of particles
local function simpleParticleBurst(effectTemplate: BasePart, cframe: CFrame, attachTo: BasePart?)
	local effect = effectTemplate:Clone()
	effect.CFrame = if attachTo then attachTo.CFrame * cframe else cframe
	effect.Parent = Workspace

	if attachTo then
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = attachTo
		weld.Part1 = effect
		weld.Parent = effect
	end

	local lifetime = 0

	-- Get all the particle emitters and have them emit, as well as get the maximum particle lifetime
	for _, v in effect:GetDescendants() do
		if not v:IsA("ParticleEmitter") then
			continue
		end

		lifetime = math.max(lifetime, v.Lifetime.Max)

		local emitAmount = v:GetAttribute(EMIT_AMOUNT_ATTRIBUTE)
		if emitAmount then
			v:Emit(emitAmount)
		end
	end

	task.delay(lifetime, function()
		-- Wait for the particles to fade before destroying the effect
		effect:Destroy()
	end)
end

return simpleParticleBurst
