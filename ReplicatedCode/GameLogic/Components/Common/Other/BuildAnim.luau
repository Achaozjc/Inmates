--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")


local creatAnimation = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.VFX.CreateAnimation)
local BuildAnimationsEnum = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Enums.BuildAnimationsEnum)


local function GetAnimationController(instance :Model)
	for _, anim in pairs(instance:GetDescendants()) do
		if anim:IsA("AnimationController") then
			return anim
		end
	end
	local animC = Instance.new("AnimationController")
	animC.Parent = instance
	return animC
end

local BuildAnim = {}
BuildAnim.__index = BuildAnim

export type ClassType = typeof(setmetatable({} :: {
	_instance: Model,
	_animTrack: AnimationTrack?
}, BuildAnim))

function BuildAnim.new(instance: Model): ClassType
	local self = {
		_instance = instance,
		_animTrack = nil
	}

	setmetatable(self, BuildAnim)
	
	--if not isTouch then
	--	self:setup()
	--end
	self:setup()
	return self
end



function BuildAnim.setup(self: ClassType)
	local buildName = self._instance.Name
	local animId = self._instance:GetAttribute("animeId") or BuildAnimationsEnum[buildName]
	local animationController = self._instance:FindFirstChild("AnimationController") or 
		self._instance:FindFirstChild("Humanoid")
	if not animationController then
		animationController = GetAnimationController(self._instance) :: AnimationController | Humanoid
	end
	
	if animationController and animId then
		local animator = animationController:WaitForChild("Animator") :: Animator
		local animTrack = animator:LoadAnimation(creatAnimation.create(animId)) ::AnimationTrack
		animTrack:Play()
		self._animTrack = animTrack
	end
	self:listen()
end

function BuildAnim.listen(self: ClassType)

end

function BuildAnim.destroy(self: ClassType)
	if self._animTrack then
		self._animTrack:Stop()
		self._animTrack:Destroy()
	end
end

return BuildAnim

