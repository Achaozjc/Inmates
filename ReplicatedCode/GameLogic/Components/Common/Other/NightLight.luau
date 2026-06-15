--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Janitor = require(ReplicatedStorage.ReplicatedCode.Framework.Packages.Janitor)
local AttributeEnum = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Enums.AttributeEnum)

-- 与 DayNight 阶段解耦：仅按游戏内时钟，18:00 开灯、7:00 关灯
local LIGHT_ON_START_HOUR = 18
local LIGHT_OFF_END_HOUR = 7

local Nightlight = {}
Nightlight.__index = Nightlight

export type ClassType = typeof(setmetatable(
    {} :: {
        _light: Light,
        _janitor: Janitor.Janitor,
    },
    Nightlight
))

function Nightlight.new(instance: Instance): ClassType
    local self = setmetatable({
        _light = instance :: Light,
        _janitor = Janitor.new(),
    }, Nightlight)

    self:setup()
    self:listen()
    return self
end

function Nightlight.setup(self: ClassType)
    self:_updateEnabled()
end

function Nightlight.listen(self: ClassType)
    -- Clock 为展示字符串；判定时刻必须用服务端写入的 ClockTime（number）
    self._janitor:Add(
        ReplicatedStorage:GetAttributeChangedSignal(AttributeEnum.ClockTime):Connect(function()
            self:_updateEnabled()
        end),
        "Disconnect"
    )
end

local function shouldNightLightBeOn(clockTime: number): boolean
    return clockTime >= LIGHT_ON_START_HOUR or clockTime < LIGHT_OFF_END_HOUR
end

function Nightlight._updateEnabled(self: ClassType)
    local clockTime = ReplicatedStorage:GetAttribute(AttributeEnum.ClockTime)
    if type(clockTime) ~= "number" then
        self._light.Enabled = false
        return
    end
    self._light.Enabled = shouldNightLightBeOn(clockTime)
end

function Nightlight.destroy(self: ClassType)
    self._janitor:Destroy()
end

return Nightlight
