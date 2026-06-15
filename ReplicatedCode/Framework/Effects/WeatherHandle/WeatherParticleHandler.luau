local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserGameSettings = UserSettings():GetService("UserGameSettings")
local Workspace = game:GetService("Workspace")
local CurrentCamera = Workspace.CurrentCamera :: Camera

local AttributeEnum = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Enums.AttributeEnum)

local WeatherParticleHandler = {}
WeatherParticleHandler.__index = WeatherParticleHandler

local RAYCAST_COLLISION_GROUP = "Default"
local random = Random.new()

function WeatherParticleHandler.new(config)
	local self = setmetatable({}, WeatherParticleHandler)

	self.Config = config
	self.Enabled = false
	self.Disabled = true

	self.GlobalModifier = Instance.new("NumberValue")
	self.GlobalModifier.Value = 1

	self.Color = Instance.new("Color3Value")
	self.Color.Value = config.DefaultColor or Color3.new(1, 1, 1)

	self.Transparency = Instance.new("NumberValue")
	self.Transparency.Value = config.DefaultTransparency or 0

	self.SpeedRatio = Instance.new("NumberValue")
	self.SpeedRatio.Value = config.DefaultSpeedRatio or 1

	self.IntensityRatio = Instance.new("NumberValue")
	self.IntensityRatio.Value = config.DefaultIntensityRatio or 1

	self.LightEmission = Instance.new("NumberValue")
	self.LightEmission.Value = config.DefaultLightEmission or 0

	self.LightInfluence = Instance.new("NumberValue")
	self.LightInfluence.Value = config.DefaultLightInfluence or 0

	self.WeatherDirection = Instance.new("Vector3Value")
	self.WeatherDirection.Value = config.DefaultDirection or Vector3.new(0, -1, 0)

	self.Connections = {}
	self.RaycastParam = RaycastParams.new()
	self.RaycastParam.CollisionGroup = RAYCAST_COLLISION_GROUP

	self.CurrentCeiling = nil
	self.Inside = true
	self.VolumeTarget = 0

	self.StraightLowAlpha = 1
	self.TopdownLowAlpha = 1
	self.IntensityOccluded = 0
	self.NumSplashes = 0

	self.VolumeScanGrid = {}
	local scanRadius = config.VolumeScanRadius or 35
	if config.VolumeScanGrid then
		for _, v in pairs(config.VolumeScanGrid) do
			table.insert(self.VolumeScanGrid, v * scanRadius)
		end
		table.sort(self.VolumeScanGrid, function(a, b)
			return a.Magnitude < b.Magnitude
		end)
	end

	self:_setupSound()
	self:_setupEmitters()
	self:_setupAttachments()
	self:_setupPropertyListeners()

	self:_updateTransparency(self.Transparency.Value)
	self:_updateIntensity(self.IntensityRatio.Value)

	return self
end

function WeatherParticleHandler:_setupSound()
	-- 使用 AudioPlayer + Wire 到 Ambient Bus
	local ambientBus = SoundService:FindFirstChild("Audio")
	local ambientFader = ambientBus and ambientBus:FindFirstChild("Busses")
		and ambientBus.Busses:FindFirstChild("Ambient")
		and ambientBus.Busses.Ambient:FindFirstChild("AudioFader")

	self.sound = Instance.new("AudioPlayer")
	self.sound.Name = self.Config.Name .. "Sound"
	self.sound.Volume = 0
	self.sound.Asset = self.Config.SoundId
	self.sound.Looping = true
	self.sound.Parent = SoundService

	if ambientFader then
		local wire = Instance.new("Wire")
		wire.Name = "Wire"
		wire.SourceInstance = self.sound
		wire.SourceName = "Output"
		wire.TargetInstance = ambientFader
		wire.TargetName = "Input"
		wire.Parent = self.sound
	end
end

function WeatherParticleHandler:_setupEmitters()
	self.Emitter = Instance.new("Part") :: BasePart
	self.Emitter.Transparency = 1
	self.Emitter.Anchored = true
	self.Emitter.CanCollide = false
	self.Emitter.CastShadow = false
	self.Emitter.CanTouch = false
	self.Emitter.CanQuery = false
	self.Emitter.Locked = false
	self.Emitter.Archivable = false
	self.Emitter.Name = "__" .. self.Config.Name .. "Emitter"
	self.Emitter.Size = self.Config.MinSize or Vector3.new(0.05, 0.05, 0.05)

	self.StraightEmitter = self.Config.StraightParticle:Clone()
	self.StraightEmitter.Name = "Straight"
	self.StraightEmitter.Enabled = false
	self.StraightEmitter.Parent = self.Emitter

	self.TopDownEmitter = self.Config.TopDownParticle:Clone()
	self.TopDownEmitter.Name = "TopDown"
	self.TopDownEmitter.Enabled = false
	self.TopDownEmitter.Parent = self.Emitter
end

function WeatherParticleHandler:_setupAttachments()
	self.SplashAttachments = {}
	self.OccludedAttachments = {}

	local splashNum = self.Config.SplashNum or 10

	for i = 1, splashNum do
		local splashAtt = Instance.new("Attachment")
		splashAtt.Name = "__" .. self.Config.Name .. "SplashAtt"

		if self.Config.SplashParticle then
			local splash = self.Config.SplashParticle:Clone()
			splash.Parent = splashAtt
		end
		splashAtt.Archivable = false
		table.insert(self.SplashAttachments, splashAtt)

		local occAtt = Instance.new("Attachment")
		occAtt.Name = "__" .. self.Config.Name .. "OccludedAtt"

		local straightOcc = self.Config.StraightParticle:Clone()
		straightOcc.Name = "Straight"
		if self.Config.OccludedStraightSpeed then
			straightOcc.Speed = self.Config.OccludedStraightSpeed
		end
		if self.Config.OccludedStraightLifetime then
			straightOcc.Lifetime = self.Config.OccludedStraightLifetime
		end
		if self.Config.OccludedStraightSpread then
			straightOcc.SpreadAngle = self.Config.OccludedStraightSpread
		end
		straightOcc.Enabled = false
		straightOcc.Parent = occAtt

		local topDownOcc = self.Config.TopDownParticle:Clone()
		topDownOcc.Name = "TopDown"
		if self.Config.OccludedTopDownSpeed then
			topDownOcc.Speed = self.Config.OccludedTopDownSpeed
		end
		if self.Config.OccludedTopDownLifetime then
			topDownOcc.Lifetime = self.Config.OccludedTopDownLifetime
		end
		if self.Config.OccludedTopDownSpread then
			topDownOcc.SpreadAngle = self.Config.OccludedTopDownSpread
		end
		topDownOcc.Enabled = false
		topDownOcc.Parent = occAtt

		occAtt.Archivable = false
		table.insert(self.OccludedAttachments, occAtt)
	end
end

function WeatherParticleHandler:_setupPropertyListeners()
	self.GlobalModifier.Changed:Connect(function()
		self:_updateTransparency(self.Transparency.Value)
	end)
	self.Transparency.Changed:Connect(function(val)
		self:_updateTransparency(val)
	end)

	self.Color.Changed:Connect(function(val)
		local colSeq = ColorSequence.new(val)
		self.StraightEmitter.Color = colSeq
		self.TopDownEmitter.Color = colSeq
		for _, att in ipairs(self.SplashAttachments) do
			if att:FindFirstChildWhichIsA("ParticleEmitter") then
				att:FindFirstChildWhichIsA("ParticleEmitter").Color = colSeq
			end
		end
		for _, att in ipairs(self.OccludedAttachments) do
			for _, emitter in ipairs(att:GetChildren()) do
				if emitter:IsA("ParticleEmitter") then
					emitter.Color = colSeq
				end
			end
		end
	end)

	self.SpeedRatio.Changed:Connect(function(val)
		local straightSpeed = self.Config.StraightMaxSpeed or 60
		local topDownSpeed = self.Config.TopDownMaxSpeed or 60
		self.StraightEmitter.Speed = NumberRange.new(val * straightSpeed)
		self.TopDownEmitter.Speed = NumberRange.new(val * topDownSpeed)
	end)

	self.IntensityRatio.Changed:Connect(function(val)
		self:_updateIntensity(val)
		
		-- 实时更新声音音量，使其随 intensity 变化
		if not self.Disabled and self.Enabled then
			TweenService:Create(self.sound, TweenInfo.new(1), { Volume = self.VolumeTarget * val }):Play()
		end
	end)

	self.LightEmission.Changed:Connect(function(val)
		self.StraightEmitter.LightEmission = val
		self.TopDownEmitter.LightEmission = val
		for _, att in ipairs(self.SplashAttachments) do
			if att:FindFirstChildWhichIsA("ParticleEmitter") then
				att:FindFirstChildWhichIsA("ParticleEmitter").LightEmission = val
			end
		end
		for _, att in ipairs(self.OccludedAttachments) do
			for _, e in ipairs(att:GetChildren()) do
				if e:IsA("ParticleEmitter") then
					e.LightEmission = val
				end
			end
		end
	end)

	self.LightInfluence.Changed:Connect(function(val)
		self.StraightEmitter.LightInfluence = val
		for _, att in ipairs(self.OccludedAttachments) do
			for _, e in ipairs(att:GetChildren()) do
				if e:IsA("ParticleEmitter") then
					e.LightInfluence = val
				end
			end
		end
		for _, att in ipairs(self.SplashAttachments) do
			if att:FindFirstChildWhichIsA("ParticleEmitter") then
				att:FindFirstChildWhichIsA("ParticleEmitter").LightInfluence = val
			end
		end
	end)

	UserGameSettings:GetPropertyChangedSignal("SavedQualityLevel"):Connect(function()
		self:_updateIntensity(self.IntensityRatio.Value)
	end)

	-- Low Detail 设置变更时刷新粒子数量
	local localPlayer = Players.LocalPlayer
	if localPlayer then
		localPlayer:GetAttributeChangedSignal(AttributeEnum.Setting.lowDetail):Connect(function()
			self:_updateIntensity(self.IntensityRatio.Value)
		end)
	end
end

function WeatherParticleHandler:_updateTransparency(val)
	local opacity = (1 - val) * (1 - self.GlobalModifier.Value)
	local transparency = 1 - opacity

	local straightAlphaLow = (self.Config.StraightAlphaLow or 0.7)
	local splashAlphaLow = (self.Config.SplashAlphaLow or 0.6)
	local t1 = self.Config.TransparencyT1 or 0.25
	local t2 = self.Config.TransparencyT2 or 0.75

	self.StraightLowAlpha = straightAlphaLow * opacity + transparency

	local splashSequence = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1, 0),
		NumberSequenceKeypoint.new(t1, opacity * splashAlphaLow + transparency, 0),
		NumberSequenceKeypoint.new(t2, opacity * splashAlphaLow + transparency, 0),
		NumberSequenceKeypoint.new(1, 1, 0),
	})

	for _, att in ipairs(self.SplashAttachments) do
		local splash = att:FindFirstChildWhichIsA("ParticleEmitter")
		if splash then
			splash.Transparency = splashSequence
		end
	end
end

function WeatherParticleHandler:_getQualityMultiplier()
	-- Low Detail 模式下直接返回极低倍率
	local localPlayer = Players.LocalPlayer
	if localPlayer and localPlayer:GetAttribute(AttributeEnum.Setting.lowDetail) == true then
		return 0
	end

	local qualityLevel = UserGameSettings.SavedQualityLevel
	if qualityLevel == Enum.SavedQualitySetting.Automatic then
		return 1
	end
	local qValue = qualityLevel.Value
	if qValue >= 8 then
		return 1
	elseif qValue >= 5 then
		return 0.5
	else
		return 0.25
	end
end

function WeatherParticleHandler:_updateIntensity(val)
	local straightRate = self.Config.StraightMaxRate or 500
	local topDownRate = self.Config.TopDownMaxRate or 600

	self.StraightEmitter.Rate = straightRate * val
	self.TopDownEmitter.Rate = topDownRate * val

	local occMaxInt = self.Config.OccludedMaxIntensity or 2
	self.IntensityOccluded = math.ceil(occMaxInt * val)

	local splashNum = self.Config.SplashNum or 10
	self.NumSplashes = math.floor(splashNum * val * self:_getQualityMultiplier())
end

function WeatherParticleHandler:raycast(origin, dir)
	return Workspace:Raycast(origin, dir, self.RaycastParam)
end

function WeatherParticleHandler:Enable(tweenInfo)
	if self.Enabled then
		return
	end
	self.Enabled = true

	self:DisconnectLoop()

	self.StraightEmitter.Enabled = true
	self.TopDownEmitter.Enabled = true
	self.Emitter.Parent = CurrentCamera

	for i = 1, #self.SplashAttachments do
		self.SplashAttachments[i].Parent = workspace.Terrain
		self.OccludedAttachments[i].Parent = workspace.Terrain
	end

	self:ConnectLoop()

	if tweenInfo then
		TweenService:Create(self.GlobalModifier, tweenInfo, { Value = 0 }):Play()
	else
		self.GlobalModifier.Value = 0
	end

	if not self.sound.IsPlaying then
		self.sound:Play()
		self.sound.TimePosition = random:NextNumber() * self.sound.TimeLength
	end

	self.Disabled = false
end

function WeatherParticleHandler:Disable(tweenInfo)
	if not self.Enabled then
		return
	end
	self.Enabled = false

	if tweenInfo then
		local tween = TweenService:Create(self.GlobalModifier, tweenInfo, { Value = 1 })
		tween.Completed:Once(function(state)
			if state == Enum.PlaybackState.Completed then
				self:_finalizeDisable()
			end
			tween:Destroy()
		end)
		tween:Play()
		self:_disableSound(tweenInfo)
	else
		self.GlobalModifier.Value = 1
		self:_finalizeDisable()
	end

	self.Disabled = true
end

function WeatherParticleHandler:_disableSound(tweenInfo)
	self.VolumeTarget = 0
	local tween = TweenService:Create(self.sound, tweenInfo, { Volume = 0 })
	tween.Completed:Once(function(state)
		if state == Enum.PlaybackState.Completed then
			self.sound:Stop()
		end
		tween:Destroy()
	end)
	tween:Play()
end

function WeatherParticleHandler:_finalizeDisable()
	self:DisconnectLoop()
	self.StraightEmitter.Enabled = false
	self.TopDownEmitter.Enabled = false
	self.Emitter.Size = self.Config.MinSize or Vector3.new(0.05, 0.05, 0.05)

	if not self.Disabled then
		self:_disableSound(TweenInfo.new(self.Config.SoundFadeOutTime or 1))
	end
end

function WeatherParticleHandler:ConnectLoop()
	local rand = Random.new()
	local updatePeriod = self.Config.UpdatePeriod or 6
	local indoorCheckPeriod = self.Config.IndoorCheckPeriod or 15

	local frame = updatePeriod
	local indoorCheckFrame = indoorCheckPeriod
	local lastResult = nil
	local scanHeight = self.Config.ScanHeight or 1000

	table.insert(
		self.Connections,
		RunService.RenderStepped:Connect(function()
			local dir = self.WeatherDirection.Value.Unit

			-- ── 室内检测（原回调 1） ──────────────────────────────
			indoorCheckFrame = indoorCheckFrame + 1
			if indoorCheckFrame >= indoorCheckPeriod then
				indoorCheckFrame = 0
				lastResult = self:raycast(CurrentCamera.CFrame.Position, -dir * scanHeight)
			end

			local result = lastResult
			if
				not result
				or (not self.CurrentCeiling or CurrentCamera.CFrame.Position.Y <= self.CurrentCeiling)
					and not result.Instance
			then
				if self.VolumeTarget < 1 and not self.Disabled then
					self.VolumeTarget = 1
					TweenService:Create(self.sound, TweenInfo.new(0.5), { Volume = self.IntensityRatio.Value }):Play()
				end

				frame = updatePeriod

				local lookVec = CurrentCamera.CFrame.LookVector
				local t = math.abs(lookVec:Dot(dir))

				local center = CurrentCamera.CFrame.Position
				local right = lookVec:Cross(-dir)
				right = right.Magnitude > 0.001 and right.Unit or -dir
				local forward = dir:Cross(right).Unit

				local dimDef = self.Config.EmitterDimDefault or 40
				local dimMaxFwd = self.Config.EmitterDimMaxForward or 100

				self.Emitter.Size = Vector3.new(dimDef, dimDef, dimDef + (1 - t) * (dimMaxFwd - dimDef))

				local upMod = self.Config.EmitterUpModifier or 20

				self.Emitter.CFrame = CFrame.new(
					center.X,
					center.Y,
					center.Z,
					right.X,
					-dir.X,
					forward.X,
					right.Y,
					-dir.Y,
					forward.Y,
					right.Z,
					-dir.Z,
					forward.Z
				) + (1 - t) * lookVec * self.Emitter.Size.Z / 3 - t * dir * upMod

				self.StraightEmitter.Enabled = true
				self.TopDownEmitter.Enabled = true
				self.Inside = false
			else
				self.StraightEmitter.Enabled = false
				self.TopDownEmitter.Enabled = false
				self.Inside = true
			end

			-- ── 透明度 / 旋转 / splash（原回调 2） ────────────────
			frame = frame + 1

			if frame >= updatePeriod then
				local t = math.abs(CurrentCamera.CFrame.LookVector:Dot(dir))
				local t1 = self.Config.TransparencyT1 or 0.25
				local t2 = self.Config.TransparencyT2 or 0.75
				local topDownAlphaLow = self.Config.TopDownAlphaLow or 0.85

				local straightSequence = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1, 0),
					NumberSequenceKeypoint.new(t1, (1 - t) * self.StraightLowAlpha + t, 0),
					NumberSequenceKeypoint.new(t2, (1 - t) * self.StraightLowAlpha + t, 0),
					NumberSequenceKeypoint.new(1, 1, 0),
				})
				local topdownSequence = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1, 0),
					NumberSequenceKeypoint.new(t1, t * topDownAlphaLow + (1 - t), 0),
					NumberSequenceKeypoint.new(t2, t * topDownAlphaLow + (1 - t), 0),
					NumberSequenceKeypoint.new(1, 1, 0),
				})

				local mapped = CurrentCamera.CFrame:inverse() * (CurrentCamera.CFrame.Position - dir)
				local straightRotation = NumberRange.new(math.deg(math.atan2(-mapped.X, mapped.Y)))

				if self.Inside then
					for _, att in ipairs(self.OccludedAttachments) do
						local s = att:FindFirstChild("Straight")
						local td = att:FindFirstChild("TopDown")
						if s then
							s.Transparency = straightSequence
							s.Rotation = straightRotation
						end
						if td then
							td.Transparency = topdownSequence
						end
					end

					if not self.Disabled then
						local volume = 0
						if not self.CurrentCeiling or CurrentCamera.CFrame.Position.Y <= self.CurrentCeiling then
							local minDistance = self.Config.VolumeScanRadius or 35
							local rayDir = -dir * scanHeight

							if #self.VolumeScanGrid > 0 then
								for i = 1, #self.VolumeScanGrid do
									if not self:raycast(CurrentCamera.CFrame * self.VolumeScanGrid[i], rayDir) then
										minDistance = self.VolumeScanGrid[i].Magnitude
										break
									end
								end
								volume = 1 - minDistance / (self.Config.VolumeScanRadius or 35)
							end
						end

						if math.abs(volume - self.VolumeTarget) > 0.01 then
							self.VolumeTarget = volume
							TweenService:Create(self.sound, TweenInfo.new(1), { Volume = self.VolumeTarget * self.IntensityRatio.Value }):Play()
						end
					end
				else
					self.StraightEmitter.Transparency = straightSequence
					self.StraightEmitter.Rotation = straightRotation
					self.TopDownEmitter.Transparency = topdownSequence
				end
				frame = 0
			end

			local center = CurrentCamera.CFrame.Position
			local right = CurrentCamera.CFrame.LookVector:Cross(-dir)
			right = right.Magnitude > 0.001 and right.Unit or -dir
			local forward = dir:Cross(right).Unit

			local transform = CFrame.new(
				center.X,
				center.Y,
				center.Z,
				right.X,
				-dir.X,
				forward.X,
				right.Y,
				-dir.Y,
				forward.Y,
				right.Z,
				-dir.Z,
				forward.Z
			)

			local scanY = self.Config.OccludeCheckScanY or 550
			local rayDir = dir * scanY
			local xzMin = self.Config.OccludeCheckOffsetXZMin or -100
			local xzMax = self.Config.OccludeCheckOffsetXZMax or 100
			local offY = self.Config.OccludeCheckOffsetY or 500
			local splashCorrectionY = self.Config.SplashCorrectionY or 0.5
			local splashStraightOffsetY = self.Config.SplashStraightOffsetY or 50
			local noSplashMin = self.Config.NoSplashStraightOffsetYMin or 20
			local noSplashMax = self.Config.NoSplashStraightOffsetYMax or 100

			for i = 1, self.NumSplashes do
				local splashAtt = self.SplashAttachments[i]
				local occAtt = self.OccludedAttachments[i]

				local x = rand:NextNumber(xzMin, xzMax)
				local z = rand:NextNumber(xzMin, xzMax)
				local result = self:raycast(transform * Vector3.new(x, offY, z), rayDir)

				if result then
					splashAtt.Position = result.Position + result.Normal * splashCorrectionY
					local splashEmitter = splashAtt:FindFirstChildWhichIsA("ParticleEmitter")
					if splashEmitter then
						splashEmitter:Emit(1)
					end

					if self.Inside then
						local corrected = result.Position - dir * splashStraightOffsetY
						if self.CurrentCeiling and corrected.Y > self.CurrentCeiling and dir.Y < 0 then
							corrected = corrected + dir * (self.CurrentCeiling - corrected.Y) / dir.Y
						end

						occAtt.CFrame = transform - transform.Position + corrected
						local s = occAtt:FindFirstChild("Straight")
						local td = occAtt:FindFirstChild("TopDown")
						if s then
							s:Emit(self.IntensityOccluded)
						end
						if td then
							td:Emit(self.IntensityOccluded)
						end
					end
				elseif self.Inside then
					local corrected = transform * Vector3.new(x, rand:NextNumber(noSplashMin, noSplashMax), z)
					if self.CurrentCeiling and corrected.Y > self.CurrentCeiling and dir.Y < 0 then
						corrected = corrected + dir * (self.CurrentCeiling - corrected.Y) / dir.Y
					end
					occAtt.CFrame = transform - transform.Position + corrected
					local s = occAtt:FindFirstChild("Straight")
					local td = occAtt:FindFirstChild("TopDown")
					if s then
						s:Emit(self.IntensityOccluded)
					end
					if td then
						td:Emit(self.IntensityOccluded)
					end
				end
			end
		end)
	)
end

function WeatherParticleHandler:DisconnectLoop()
	if #self.Connections > 0 then
		for _, v in pairs(self.Connections) do
			v:Disconnect()
		end
		self.Connections = {}
	end
end

function WeatherParticleHandler:_makePropertySetter(propertyName, internalValueObject)
	return function(val, tweenInfo)
		if type(val) ~= "number" then
			return
		end
		val = math.clamp(val, 0, 1)
		if tweenInfo then
			TweenService:Create(internalValueObject, tweenInfo, { Value = val }):Play()
		else
			internalValueObject.Value = val
		end
	end
end

function WeatherParticleHandler:SetCollisionMode(collisionGroup)
	self.RaycastParam.CollisionGroup = collisionGroup
end

function WeatherParticleHandler:SetCeiling(ceiling)
	self.CurrentCeiling = ceiling
end

function WeatherParticleHandler:SetColor(val, tweenInfo)
	if tweenInfo then
		TweenService:Create(self.Color, tweenInfo, { Value = val }):Play()
	else
		self.Color.Value = val
	end
end

function WeatherParticleHandler:SetTransparency(val, tweenInfo)
	val = math.clamp(val, 0, 1)
	if tweenInfo then
		TweenService:Create(self.Transparency, tweenInfo, { Value = val }):Play()
	else
		self.Transparency.Value = val
	end
end

function WeatherParticleHandler:SetDirection(val, tweenInfo)
	if val.Magnitude < 0.001 then
		val = self.Config.DefaultDirection or Vector3.new(0, -1, 0)
	end
	if tweenInfo then
		TweenService:Create(self.WeatherDirection, tweenInfo, { Value = val }):Play()
	else
		self.WeatherDirection.Value = val
	end
end

function WeatherParticleHandler:SetSpeedRatio(val, tweenInfo)
	if type(val) ~= "number" then
		return
	end
	-- SpeedRatio 允许 >1 以支持雷暴雨等高速场景
	val = math.clamp(val, 0, 2)
	if tweenInfo then
		TweenService:Create(self.SpeedRatio, tweenInfo, { Value = val }):Play()
	else
		self.SpeedRatio.Value = val
	end
end

function WeatherParticleHandler:SetIntensityRatio(val, tweenInfo)
	self:_makePropertySetter("IntensityRatio", self.IntensityRatio)(val, tweenInfo)
end

function WeatherParticleHandler:SetLightEmission(val, tweenInfo)
	self:_makePropertySetter("LightEmission", self.LightEmission)(val, tweenInfo)
end

function WeatherParticleHandler:SetLightInfluence(val, tweenInfo)
	self:_makePropertySetter("LightInfluence", self.LightInfluence)(val, tweenInfo)
end

function WeatherParticleHandler:SetVolume(val, tweenInfo) end

function WeatherParticleHandler:SetStraightTexture(asset)
	self.StraightEmitter.Texture = asset
	for _, att in ipairs(self.OccludedAttachments) do
		if att:FindFirstChild("Straight") then
			att:FindFirstChild("Straight").Texture = asset
		end
	end
end

function WeatherParticleHandler:SetSplashTexture(asset)
	for _, att in ipairs(self.SplashAttachments) do
		local s = att:FindFirstChildWhichIsA("ParticleEmitter")
		if s then
			s.Texture = asset
		end
	end
end

function WeatherParticleHandler:SetSoundId(asset)
	self.sound.Asset = asset
end

return WeatherParticleHandler
