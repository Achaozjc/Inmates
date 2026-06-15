--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TweenService = game:GetService("TweenService")

local RunService = game:GetService("RunService")
local CharacterLoadedWrapper = require(ReplicatedStorage.ReplicatedCode.Framework.Character.CharacterLoadedWrapper)
local getCodeAsset = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Instance.GetCodeAsset)

local Arrow: Model = getCodeAsset("Effects", "Arrow")
local ATTR_IN_ELEVATOR = "InElevator"

local ArrowPath = {}
ArrowPath.__index = ArrowPath

local VISIBILITYTHRESHOLD = 30 --距离阈值
local OFFSET = 5
local FLOATING_AMPLITUDE = 1 -- 漂浮的幅度
local FLOATING_SPEED = 5 -- 漂浮速度

export type ClassType = typeof(setmetatable(
	{} :: {
		_player: Player,
		_arrow: Model,
		_isEnabled: boolean,
		_heartbeatConnection: RBXScriptConnection?,
		_characterLoadedWrapper: CharacterLoadedWrapper.ClassType,
		_targetCFrame: CFrame?,
		_char: Model?,
	},
	ArrowPath
))

function ArrowPath.new(player: Player)
	local self = {
		_player = player,
		_arrow = Arrow:Clone(),
		_isEnabled = false,
		_heartbeatConnection = nil :: RBXScriptConnection?,
		_characterLoadedWrapper = CharacterLoadedWrapper.new(player),
		_targetCFrame = nil :: CFrame?,
		_char = nil :: Model?,
	}
	setmetatable(self, ArrowPath)

	self:_setup()

	return self
end

function ArrowPath._setup(self: ClassType)
	if self._characterLoadedWrapper:isLoaded() then
		self._char = self._player.Character
	end

	self._characterLoadedWrapper.loaded:Connect(function(char)
		self._char = char
	end)
end

function ArrowPath._setupTarget(self: ClassType, cframe: CFrame)
	self._targetCFrame = cframe
end

function ArrowPath._enable(self: ClassType)
	self._isEnabled = true

	self._heartbeatConnection = RunService.RenderStepped:Connect(function()
		self:_update()
	end)
end

function ArrowPath._disable(self: ClassType)
	self._isEnabled = false

	if self._heartbeatConnection then
		self._heartbeatConnection:Disconnect()
	end
end

function ArrowPath.setEnabled(self: ClassType, isEnabled: boolean)
	if isEnabled == self._isEnabled then
		return
	end

	if isEnabled then
		self._arrow.Parent = game.Workspace
		self:_enable()
	else
		self:_disable()
		self._arrow.Parent = script
	end
end

function ArrowPath._update(self: ClassType)
	if self._player:GetAttribute(ATTR_IN_ELEVATOR) then
		return
	end

	if self._char and self._targetCFrame then
		local charCFrame = self._char:GetPivot()

		local charPosition = charCFrame.Position

		local targetPosition = self._targetCFrame.Position
		-- 计算箭头与目标的距离
		local distance = (charPosition - targetPosition).Magnitude

		local oldCFrame = self._arrow:GetPivot()

		local lookAtCFrame: CFrame

		if distance > VISIBILITYTHRESHOLD then
			local directionToTarget = (targetPosition - charPosition).Unit

			local arrowPosition = Vector3.new(
				charPosition.X + directionToTarget.X * OFFSET,
				charPosition.Y, -- 使用角色的Y高度
				charPosition.Z + directionToTarget.Z * OFFSET
			)

			targetPosition = Vector3.new(self._targetCFrame.Position.X, arrowPosition.Y, self._targetCFrame.Position.Z)

			lookAtCFrame = CFrame.lookAt(arrowPosition, targetPosition, Vector3.yAxis)
		else
			-- 计算浮动
			local timeElapsed = os.clock() -- 获取当前时间
			local floatY = math.sin(timeElapsed * FLOATING_SPEED) * FLOATING_AMPLITUDE

			local arrowPosition = targetPosition + Vector3.new(0, OFFSET + floatY, 0)

			lookAtCFrame = CFrame.lookAt(arrowPosition, targetPosition, Vector3.yAxis)
		end

		--local newCFrame = oldCFrame:Lerp(lookAtCFrame, 0.5)

		self._arrow:PivotTo(lookAtCFrame)
	end
end

function ArrowPath._setTransparency(self: ClassType, bool: boolean)
	for _, part in pairs(self._arrow:GetChildren()) do
		if part:IsA("BasePart") then
			part.Transparency = bool and 0 or 1
		end
	end
end

function ArrowPath.destroy(self: ClassType)
	if self._heartbeatConnection then
		self._heartbeatConnection:Disconnect()
	end

	self._arrow:Destroy()
	self._characterLoadedWrapper:destroy()
end

return ArrowPath
