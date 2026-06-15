--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--[[
	Creates a guiding beam from the bottom of the local character to a destination attachment
--]]

local Players = game:GetService("Players")

local BeamBetween = require(ReplicatedStorage.ReplicatedCode.Framework.Effects.BeamBetween)
local CharacterLoadedWrapper = require(ReplicatedStorage.ReplicatedCode.Framework.Character.CharacterLoadedWrapper)

local instances = ReplicatedStorage:WaitForChild("Instances")
local prefabs = instances:WaitForChild("Prefabs")
local rawBeam = prefabs:WaitForChild("CharacterBeamPrefab") :: Instance
assert(rawBeam:IsA("Beam"), "ReplicatedStorage/Instances/Prefabs/CharacterBeamPrefab must be a Beam")
local characterBeamPrefab: Beam = rawBeam :: Beam
local localPlayer = Players.LocalPlayer :: Player

-- Studio 下打印 Beam 实例状态，便于排查「逻辑到了但看不见线」
local DEBUG_DUMP_GUIDE_BEAM = false

local function _debugLogNewBeam(beam: Beam)
	if not DEBUG_DUMP_GUIDE_BEAM then
		return
	end
	print("[CharacterPath] new() called, beam=", beam, "name=", beam.Name, "parent=", beam.Parent)
end

-- 将当前 Beam 的关键属性打到输出窗口（中文注释：仅调试）
local function _debugDumpGuideBeam(beam: Beam, whenLabel: string)
	if not DEBUG_DUMP_GUIDE_BEAM then
		return
	end
	local a0 = beam.Attachment0
	local a1 = beam.Attachment1
	print("[CharacterPath][BeamDump] ========== " .. whenLabel .. " ==========")
	print("[CharacterPath][BeamDump] Beam.Name=" .. beam.Name .. " FullName=" .. beam:GetFullName())
	print("[CharacterPath][BeamDump] Parent=" .. (beam.Parent and beam.Parent:GetFullName() or "nil"))
	print("[CharacterPath][BeamDump] Enabled=" .. tostring(beam.Enabled))
	print(string.format("[CharacterPath][BeamDump] Width0=%s Width1=%s", tostring(beam.Width0), tostring(beam.Width1)))
	print(string.format("[CharacterPath][BeamDump] FaceCamera=%s LightEmission=%s", tostring(beam.FaceCamera), tostring(beam.LightEmission)))
	print("[CharacterPath][BeamDump] Transparency=" .. tostring(beam.Transparency))
	print("[CharacterPath][BeamDump] Texture=" .. tostring(beam.Texture))
	print("[CharacterPath][BeamDump] Attachment0=" .. (a0 and a0:GetFullName() or "nil"))
	if a0 then
		print("[CharacterPath][BeamDump] Attachment0.WorldPosition=" .. tostring(a0.WorldPosition))
	end
	print("[CharacterPath][BeamDump] Attachment1=" .. (a1 and a1:GetFullName() or "nil"))
	if a1 then
		print("[CharacterPath][BeamDump] Attachment1.WorldPosition=" .. tostring(a1.WorldPosition))
	end
	if a0 and a1 then
		print("[CharacterPath][BeamDump] distAttachments=" .. tostring((a0.WorldPosition - a1.WorldPosition).Magnitude))
	end
	print("[CharacterPath][BeamDump] ========================================")
end

-- 计算角色“脚底中心”在指定基准零件的局部坐标，兼容 R6/R15
local function _calcFootLocalPosition(character: Model, basePart: BasePart): Vector3
	local bboxCFrame, bboxSize = character:GetBoundingBox()
	local footWorld = bboxCFrame.Position - Vector3.new(0, bboxSize.Y * 0.5, 0)
	return basePart.CFrame:PointToObjectSpace(footWorld)
end

local CharacterPath = {}
CharacterPath.__index = CharacterPath

export type ClassType = typeof(setmetatable(
	{} :: {
		_characterLoadedWrapper: CharacterLoadedWrapper.ClassType,
		_beamBetween: BeamBetween.ClassType,
		_connections: { any },
		_targetAttachment: Attachment,
		_targetCFrame: CFrame?,
		_beam: Beam,
		_charAttachment: Attachment?,
	},
	CharacterPath
))

function CharacterPath.new()
	local self = {
		_characterLoadedWrapper = CharacterLoadedWrapper.new(localPlayer),
		_connections = {} :: { any },
		_targetAttachment = Instance.new("Attachment") :: Attachment,
		_beam = characterBeamPrefab:Clone(),
		_charAttachment = nil :: Attachment?,
	}
	setmetatable(self, CharacterPath)
	_debugLogNewBeam(self._beam)

	self._beamBetween = BeamBetween.new(self._targetAttachment, self._beam)

	self:_setup()

	return self
end

function CharacterPath._setup(self: ClassType)
	--if self._characterLoadedWrapper:isLoaded() then
	--	self:_makeBeamFromCharacterToAttachment(targetAttachment)
	--end
	self._targetAttachment.Parent = game.Workspace.Terrain

	local characterLoadedConnection = self._characterLoadedWrapper.loaded:Connect(function()
		if self._targetCFrame then
			self:_makeBeamFromCharacterToAttachment(self._targetCFrame)
		end
	end)

	local characterDiedConnection = self._characterLoadedWrapper.died:Connect(function()
		if self._charAttachment then
			self._charAttachment:Destroy()
			-- 角色重生后需要重建新的人仔端 Attachment，否则会一直引用已销毁实例导致 Beam 丢失
			self._charAttachment = nil
		end
	end)
	table.insert(self._connections, characterLoadedConnection)
	table.insert(self._connections, characterDiedConnection)
end

function CharacterPath._makeBeamFromCharacterToAttachment(self: ClassType, cframe: CFrame)
	self._targetCFrame = cframe

	if not self._characterLoadedWrapper:isLoaded() then
		self._characterLoadedWrapper.loaded:Wait()
	end

	if self._targetCFrame then
		self._beamBetween:_setTarget(self._targetCFrame)
	end

	if not self._charAttachment then
		local character = localPlayer.Character :: Model
		character:WaitForChild("Humanoid")

		local attachment0 = Instance.new("Attachment") :: Attachment
		local basePart = (character:FindFirstChild("HumanoidRootPart") :: BasePart?) or character.PrimaryPart
		assert(basePart, "Character has no valid base part for beam attachment")
		-- 脚底位置向上偏移 3 格，避免光束陷入地面，保持在腰胸附近
		attachment0.Position = _calcFootLocalPosition(character, basePart) + Vector3.new(0, 3, 0)
		attachment0.Parent = basePart

		self._charAttachment = attachment0
	end

	if self._charAttachment then
		self._beamBetween:_setupAttach0(self._charAttachment)
		self:setEnabled(true)
		_debugDumpGuideBeam(self._beam, "right after setEnabled(true)")
		-- 下一帧再转储一次（Heartbeat 会更新 Attachment 朝向）
		if DEBUG_DUMP_GUIDE_BEAM then
			task.defer(function()
				task.wait()
				if self._beam and self._beam.Parent then
					_debugDumpGuideBeam(self._beam, "after 1 frame")
				else
					print("[CharacterPath][BeamDump] after 1 frame: Beam missing or unparented (destroyed?)")
				end
			end)
		end
	end
end

function CharacterPath:setTarget(cframe: CFrame)
	self:_makeBeamFromCharacterToAttachment(cframe)
end

function CharacterPath:setEnabled(isEnabled: boolean)
	self._beamBetween:setEnabled(isEnabled)
end

function CharacterPath.destroy(self: ClassType)
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end

	if self._beamBetween then
		self._beamBetween:destroy()
	end
	if self._charAttachment then
		self._charAttachment:Destroy()
	end

	self._characterLoadedWrapper:destroy()
end

return CharacterPath
