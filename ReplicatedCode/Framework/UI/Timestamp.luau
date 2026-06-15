local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local TimestampCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.TimestampCategory)
local Janitor = require(ReplicatedStorage.ReplicatedCode.Framework.Packages.Janitor)
local formatTime = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Time.FormatTime)
local formatTimestamp = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Time.FormatTimestamp)
local Network = require(ReplicatedStorage.ReplicatedCode.Framework.Core.Network)
local RemoteEventName = require(ReplicatedStorage.ReplicatedCode.Framework.Core.Network.RemoteName.RemoteEventName)
local RemoteFunctionName = require(ReplicatedStorage.ReplicatedCode.Framework.Core.Network.RemoteName.RemoteFunctionName)

local TWEEN_INFO = TweenInfo.new(0.2)
local UPDATE_INTERVAL = 1 -- 秒级更新时间

local Timestamp = {}
Timestamp.__index = Timestamp

-- 可选：赛季等超长倒计时（>24h 用 FormatTimestamp，否则 FormatTime）；到期整行文案
export type TimestampExtraOptions = {
	expiredText: string?,
	useSplitLongCountdown: boolean?,
}

export type ClassType = typeof(setmetatable(
	{} :: {
		_janitor: Janitor.Janitor,
		_textLabel: TextLabel,
		_timeKey: TimestampCategory.EnumType,
		_leftTime: number,
		_prefix: string,
		_defaultColor: Color3,
		_lastUpdate: number?,
		_options: TimestampExtraOptions?,
	},
	Timestamp
))

-- 统一的 Heartbeat 调度，避免为每个实例单独创建连接
local activeInstances: { ClassType } = {}
local heartbeatConnection: RBXScriptConnection? = nil

local function onHeartbeat()
	if #activeInstances == 0 then
		return
	end

	local now = os.clock()
	local serverTimeNow = Workspace:GetServerTimeNow()

	for _, instance in ipairs(activeInstances) do
		local lastUpdate = instance._lastUpdate or 0
		if now - lastUpdate >= UPDATE_INTERVAL then
			instance._lastUpdate = now

			local remainingSec = instance._leftTime - serverTimeNow
			local opts = instance._options

			if opts and opts.useSplitLongCountdown then
				local remInt = math.max(0, math.floor(remainingSec))
				if remInt <= 0 then
					instance._textLabel.Text = opts.expiredText or "Ended"
				else
					local body: string
					if remInt > 86400 then
						body = formatTimestamp.second(remInt)
					else
						body = formatTime(remInt)
					end
					instance._textLabel.Text = string.format(instance._prefix, body)
				end
			else
				local remInt = math.max(0, math.floor(remainingSec))
				instance._textLabel.Text = string.format(instance._prefix, formatTime(remInt))
			end
		end
	end
end

local function registerInstance(instance: ClassType)
	table.insert(activeInstances, instance)

	if not heartbeatConnection then
		heartbeatConnection = RunService.Heartbeat:Connect(onHeartbeat)
	end
end

local function unregisterInstance(instance: ClassType)
	for index, value in ipairs(activeInstances) do
		if value == instance then
			table.remove(activeInstances, index)
			break
		end
	end

	if #activeInstances == 0 and heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
end


function Timestamp.new(
	textLabel: TextLabel,
	prefix: string,
	timeKey: TimestampCategory.EnumType?,
	leftTime: number?,
	options: TimestampExtraOptions?
): ClassType
	local self = {}
	setmetatable(self, Timestamp)
	self._janitor = Janitor.new()

	self._textLabel = textLabel

	self._defaultColor = self._textLabel.TextColor3

	self._prefix = prefix

	self._timeKey = timeKey
	self._leftTime = leftTime or 0
	self._lastUpdate = 0
	self._options = options

	self:_listen()

	self:_start()

	return self
end



function Timestamp._changeColor(self: ClassType, color: Color3?)
	self._textLabel.TextColor3 = color or self._defaultColor
end


function Timestamp._updatePrefix(self: ClassType, prefix: string)
	self._prefix = prefix
end

function Timestamp._updateLeftTime(self: ClassType, leftTime: number)
	self._leftTime = leftTime
end

function Timestamp._start(self: ClassType)
	registerInstance(self)

	self._janitor:Add(function()
		unregisterInstance(self)
	end, true, "start")
end

function Timestamp._listen(self: ClassType)
	if self._timeKey then
		if RunService:IsClient() then
			local requestSuccess, timestamp, _ = Network.invokeServerAsync(RemoteFunctionName.Get_Timestamp, self._timeKey)
			if timestamp then
				self._leftTime = timestamp
			end

			local t = Network.t
			self._janitor:Add(Network.connectEvent(RemoteEventName.Refresh_Timestamp, function(timeKey, timestamp)
				if self._timeKey == timeKey then
					self._leftTime = timestamp
				end
			end, t.tuple(t.any, t.number)),"Disconnect")
		elseif RunService:IsServer() then
			local RefreshService = require(game.ServerScriptService.ServerCode.GameLogic.Service.Sync.RefreshService)
			self._leftTime = RefreshService.Timestamps[self._timeKey] or 0

			self._janitor:Add(RefreshService.timeStampChanged.Event:Connect(function(Timestamps)
				self._leftTime = Timestamps[self._timeKey]
			end),"Disconnect") 

		end

	end
end

function Timestamp._setVisible(self: ClassType, visible: boolean)
	self._textLabel.Visible = visible
end

function Timestamp._stop(self: ClassType)
	self._janitor:Remove("start")
end

function Timestamp.destroy(self: ClassType)
	self._janitor:Destroy()
end



return Timestamp


