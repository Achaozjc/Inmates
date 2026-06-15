--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local creatAnimation = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.VFX.CreateAnimation)
local Connections = require(ReplicatedStorage.ReplicatedCode.Framework.Infrastructure.Classes.Connections)

local _HUMANOIDHIPHEIGHT = 2
local SMALLBUTNOTZERO = 0.0001
local SPEEDTHRESHOLD = 0.75 
local _JUMPANIMTIME = 0
local _JUMPANIMDURATION = 0.31

local normalizedWalkSpeed = 0.5
local normalizedRunSpeed  = 1

export type AiAnimateProperties = {
	idle: number?, 
	walk: number?,
	run: number?,
	jump : number?,
	climb: number?,
	sit: number?,
}

local DEFAULT_ANIMS = {
	idle = 180435571, 
	walk = 180426354,
	run = 180426354,
	jump = 125750702,
	sit = 178130996,
	climb = 180436334,--76820180211136
}

local AiAnimate = {}
AiAnimate.__index = AiAnimate

export type ClassType = typeof(setmetatable(
	{} :: {
		
		model: Model,
		humanoid : Humanoid,
		animator: Animator,
		animTable: {[string] :Animation},
		animTrack: {[string] :AnimationTrack},
		
		connections: Connections.ClassType,

		currentAnimSpeed: number,
		
		runAnimTrack : AnimationTrack?,
		runAnimKeyframeHandler : RBXScriptConnection?,
		currentAnimTrack : AnimationTrack?,
		currentAnimKeyframeHandler : RBXScriptConnection?,
		
		currentAnim : string,
	},
	AiAnimate
	))


function AiAnimate.new(instance: Model, properties: AiAnimateProperties?)
	local self = {}
	setmetatable(self, AiAnimate)
	
	self.model = instance
	
	self.humanoid = self.model:WaitForChild("Humanoid") :: Humanoid 
	
	self.animator = self.humanoid:WaitForChild("Animator"):: Animator


	self.connections = Connections.new()

	self.currentAnim = ""
	self.currentAnimSpeed = 1.0

	self.runAnimTrack = nil :: AnimationTrack?
	self.runAnimKeyframeHandler = nil :: RBXScriptConnection?
	self.currentAnimTrack = nil :: AnimationTrack?
	self.currentAnimKeyframeHandler = nil :: RBXScriptConnection?

	self.animTable = {} :: { [string]: Animation }
	self.animTrack = {} :: { [string]: AnimationTrack }

	self:_setup(properties or {})

	return self
end

function AiAnimate._createAnimationTrack(self:ClassType,  properties: AiAnimateProperties)

	self.animTable = {		
		idle = creatAnimation.create(tostring(properties.idle or DEFAULT_ANIMS.idle)),
		walk = creatAnimation.create(tostring(properties.walk or DEFAULT_ANIMS.walk)),
		run = creatAnimation.create(tostring(properties.run or DEFAULT_ANIMS.run)),
		jump = creatAnimation.create(tostring(properties.jump or DEFAULT_ANIMS.jump)),
		climb = creatAnimation.create(tostring(properties.climb or DEFAULT_ANIMS.climb)),
		sit = creatAnimation.create(tostring(properties.sit or DEFAULT_ANIMS.sit)),
	}
end

function AiAnimate._getAnimationTrack(self: ClassType, animName: string): AnimationTrack?
	local loadedTrack = self.animTrack[animName]
	if loadedTrack then
		return loadedTrack
	end

	local animation = self.animTable[animName]
	if not animation then
		return nil
	end

	-- 按需加载，避免大量 NPC 一次性占满客户端 AnimationTrack 上限
	local track = self.animator:LoadAnimation(animation)
	track.Priority = Enum.AnimationPriority.Core
	self.animTrack[animName] = track
	return track
end


function AiAnimate._setup(self:ClassType, properties)
	
	self:_createAnimationTrack(properties)
	
	--local isClient = RunService:IsClient()
	
	--if isClient then
	
	--end
	local moveHandler = self.humanoid.Running:Connect(function(speed: number)
		self:onRunning(speed)
	end)
	
	local climbHandler = self.humanoid.Climbing:Connect(function(speed: number)
		self:onClimbing(speed)
	end)

	local seatedHandler = self.humanoid.Seated:Connect(function(active: boolean, _seat: Seat?)
		self:onSeated(active)
	end)
	
	self.connections:add(moveHandler, climbHandler, seatedHandler)
end



function AiAnimate.rootMotionCompensation(self:ClassType, speed: number)
	local speedScaled = speed * 1.25
	local heightScale = self:getHeightScale()
	local runSpeed = speedScaled / heightScale
	return runSpeed
end


function AiAnimate.setRunSpeed(self:ClassType, speed:number)
	local runSpeed = self:rootMotionCompensation(speed) ::number
	local walkAnimationWeight = SMALLBUTNOTZERO
	local runAnimationWeight = SMALLBUTNOTZERO

	local timeWarp = 1
	
	
	if runSpeed <= normalizedWalkSpeed then
		walkAnimationWeight = 1
		timeWarp = runSpeed/normalizedWalkSpeed
	elseif runSpeed < normalizedRunSpeed then
		local fadeInRun = (runSpeed - normalizedWalkSpeed)/(normalizedRunSpeed - normalizedWalkSpeed)
		walkAnimationWeight = 1 - fadeInRun
		runAnimationWeight  = fadeInRun
	else
		timeWarp = runSpeed/normalizedRunSpeed
		runAnimationWeight = 1
	end
	

	if self.currentAnimTrack then
		self.currentAnimTrack:AdjustWeight(walkAnimationWeight)
	end
	if self.runAnimTrack then
		self.runAnimTrack:AdjustWeight(runAnimationWeight)
	end
	if self.currentAnimTrack then
		self.currentAnimTrack:AdjustSpeed(timeWarp)
	end
	if self.runAnimTrack then
		self.runAnimTrack:AdjustSpeed(timeWarp)
	end
end

function AiAnimate:getRigScale(): number
	return self.model:GetScale()
end

function AiAnimate.getHeightScale(self: ClassType): number
	return self:getRigScale()
end




function AiAnimate.setAnimationSpeed(self:ClassType, speed : number)
	if self.currentAnim == "walk" then
		self:setRunSpeed(speed)
	else
		if speed ~= self.currentAnimSpeed and self.currentAnimTrack then
			self.currentAnimSpeed = speed
			self.currentAnimTrack:AdjustSpeed(self.currentAnimSpeed)
		end
	end
end


function AiAnimate.keyFrameReachedFunc(self:ClassType, frameName)
	if (frameName == "End") then
		if self.currentAnim == "walk" then
			if self.runAnimTrack and self.runAnimTrack.Looped ~= true then
				self.runAnimTrack.TimePosition = 0.0
			end
			if self.currentAnimTrack and self.currentAnimTrack.Looped ~= true then
				self.currentAnimTrack.TimePosition = 0.0
			end
		else
			local repeatAnim = self.currentAnim
			-- return to idle if finishing an emote

			local animSpeed = self.currentAnimSpeed
			self:playAnimation(repeatAnim, 0.15)
			self:setAnimationSpeed(animSpeed)
		end
	end
end


function AiAnimate.switchToAnim(self:ClassType, animName :string, transitionTime : number)
	if (animName ~= self.currentAnim) then
		if (self.currentAnimTrack) then
			self.currentAnimTrack:Stop(transitionTime)
		end

		if (self.runAnimTrack) then
			self.runAnimTrack:Stop(transitionTime)
			if (self.runAnimKeyframeHandler ~= nil) then
				self.runAnimKeyframeHandler:Disconnect()
				self.runAnimKeyframeHandler = nil
			end
		end

		self.currentAnimSpeed = 1.0

		-- load it to the humanoid; get AnimationTrack
		self.currentAnimTrack = self:_getAnimationTrack(animName)
		
		if self.currentAnimTrack then
			-- play the animation
			self.currentAnimTrack:Play(transitionTime)
			self.currentAnim = animName
			-- set up keyframe name triggers
			if (self.currentAnimKeyframeHandler ~= nil) then
				self.currentAnimKeyframeHandler:Disconnect()
			end
			self.currentAnimKeyframeHandler = self.currentAnimTrack.KeyframeReached:Connect(function(frameName)
				self:keyFrameReachedFunc(frameName)
			end)
		end
	

		-- check to see if we need to blend a walk/run animation
		if animName == "walk" then
			self.runAnimTrack = self:_getAnimationTrack("run")
			if self.runAnimTrack then
				self.runAnimTrack:Play(transitionTime)		

				if (self.runAnimKeyframeHandler ~= nil) then
					self.runAnimKeyframeHandler:Disconnect()
				end
				self.runAnimKeyframeHandler = self.runAnimTrack.KeyframeReached:Connect(function(frameName)
					self:keyFrameReachedFunc(frameName)
				end)	
			end		
		end
	end
end

function AiAnimate.playAnimation(self:ClassType, animName, transitionTime) 	
	self:switchToAnim(animName, transitionTime)
end



function AiAnimate.onRunning(self:ClassType, speed :number)
	local heightScale = self:getHeightScale()
	if speed > SPEEDTHRESHOLD * heightScale then
		local scale = 16.0
		self:playAnimation("walk", 0.2)
		self:setAnimationSpeed(speed / scale)
	else
		self:playAnimation("idle", 0.2)
	end
end

function AiAnimate.onClimbing(self:ClassType, speed: number)
	speed /= self:getHeightScale()

	self:playAnimation("climb", 0.1)
	self:setAnimationSpeed(speed / 12.0)
end

function AiAnimate.onSeated(self: ClassType, active: boolean)
	if active then
		self:playAnimation("sit", 0.2)
	else
		-- 起身时回到 idle，由 Running/其他状态再切到 walk 等
		self:playAnimation("idle", 0.2)
	end
end



function AiAnimate.stopAnimationTrack(self:ClassType)
	if (self.runAnimKeyframeHandler ~= nil) then
		self.runAnimKeyframeHandler:Disconnect()
		self.runAnimKeyframeHandler = nil
	end
	if (self.currentAnimKeyframeHandler ~= nil) then
		self.currentAnimKeyframeHandler:Disconnect()
		self.currentAnimKeyframeHandler = nil
	end
	if (self.currentAnimTrack ~= nil) then
		self.currentAnimTrack:Stop()
		self.currentAnimTrack:Destroy()
		self.currentAnimTrack = nil
	end

	if (self.runAnimTrack ~= nil) then
		self.runAnimTrack:Stop()
		self.runAnimTrack:Destroy()
		self.runAnimTrack = nil
	end

	for _, track in pairs(self.animTrack) do
		if track then
			track:Stop()
			track:Destroy()
		end
	end
	table.clear(self.animTrack)

	for _, animation in pairs(self.animTable) do
		animation:Destroy()
	end
	table.clear(self.animTable)
end


function AiAnimate.destroy(self:ClassType) 
	self.connections:disconnect()
	self:stopAnimationTrack()
end

return AiAnimate


