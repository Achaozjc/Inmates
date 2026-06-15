--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Network = require(ReplicatedStorage.ReplicatedCode.Framework.Core.Network)
local RemoteEventName = require(ReplicatedStorage.ReplicatedCode.Framework.Core.Network.RemoteName.RemoteEventName)
local TimeTokenCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.TimeTokenCategory)
local Connections = require(ReplicatedStorage.ReplicatedCode.Framework.Infrastructure.Classes.Connections)
local HapticController = require(ReplicatedStorage.ReplicatedCode.Framework.Input.HapticController)

local AUTO_TELEPORTINTERVAL = (TimeTokenCategory.minutes * 15)
-- 传送前 30s 内震一次警告,让玩家有时间动一下避免被踢
local AFK_WARN_BEFORE = 30

local AutoAFK = {}
AutoAFK.__index = AutoAFK

type Self = {
    _connections: Connections.ClassType,
    _lastInputTime: number,
    _warnedThisCycle: boolean,
}

export type ClassType = typeof(setmetatable({} :: Self, AutoAFK))

function AutoAFK.new(): ClassType
    local self = {
        _connections = Connections.new(),
        _lastInputTime = os.clock(),
        _warnedThisCycle = false,
    }
    setmetatable(self, AutoAFK)

    self:_setup()

    self:_timer()

    self:_listen()

    return self
end

function AutoAFK._setup(self: ClassType) end

function AutoAFK._checkOnlineTime(self: ClassType)
    local elapse = os.clock() - self._lastInputTime
    --print("空置时长：", elapse)
    -- 即将到达 AFK 阈值:手柄长震提醒,让玩家动一下刷新 _lastInputTime
    if elapse > AUTO_TELEPORTINTERVAL - AFK_WARN_BEFORE and not self._warnedThisCycle then
        self._warnedThisCycle = true
        HapticController.warn()
    end
    if elapse > AUTO_TELEPORTINTERVAL then
        -- Reset timer to prevent loop and continue checking
        self._lastInputTime = os.clock()
        self._warnedThisCycle = false
        warn("AFK teleport")
        Network.fireServer(RemoteEventName.Teleport_Select, "AFK")
    end
end

function AutoAFK._timer(self: ClassType)
    --在线时长
    local accumulatedTime = 0

    local connection = RunService.Heartbeat:Connect(function(dt)
        accumulatedTime += dt

        if accumulatedTime >= TimeTokenCategory.seconds then
            accumulatedTime -= TimeTokenCategory.seconds

            self:_checkOnlineTime()
        end
    end)

    self._connections:add(connection :: any)
end

function AutoAFK._listen(self: ClassType)
    local cooldown = 0

    local function UpdateLastInputTime()
        local now = os.clock()
        if now - cooldown < 0.5 then
            return
        end
        cooldown = now
        self._lastInputTime = now
        self._warnedThisCycle = false
    end

    local connection1 = UserInputService.InputBegan:Connect(UpdateLastInputTime)

    local connection2 = UserInputService.WindowFocused:Connect(UpdateLastInputTime)

    local connection3 = UserInputService.InputChanged:Connect(UpdateLastInputTime)

    self._connections:add(connection1 :: any, connection2 :: any, connection3 :: any)
end

function AutoAFK.destroy(self: ClassType)
    self._connections:disconnect()
end

return AutoAFK
