--!strict
--[[
	VolumeManager — 统一音量管理入口
	通过 AudioFader（新 Audio API 总线）和 ReplicatedStorage 属性（响应式）控制音量
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local VolumeManager = {}

-- 内部缓存（0-1）
local settings: { [string]: number } = {
	s_sfx = 0.5,
	s_bgm = 0.5,
	s_ambient = 0.5,
	s_world = 0.5,
}

-- 同步传统 Sound API 的 SoundGroup 音量（大部分 SFX/BGM 走此通道）
local function applySoundGroupVolume(settingKey: string, volume: number)
	local groupName = if settingKey == "s_sfx" then "SFX" elseif settingKey == "s_bgm" then "bgm" else nil
	if not groupName then
		return
	end

	local group = SoundService:FindFirstChild(groupName)
	if group and group:IsA("SoundGroup") then
		group.Volume = volume
	end
end

-- 更新单个分类的所有音量通道
local function applyVolume(settingKey: string, volume: number)
	-- 1. ReplicatedStorage 属性（供 AudioPlayer 组件等响应式监听）
	ReplicatedStorage:SetAttribute(settingKey, volume)

	-- 2. SoundGroup（SoundService.SFX / bgm 等传统音效）
	applySoundGroupVolume(settingKey, volume)

	-- 3. AudioFader（按 _category 属性匹配）
	for _, fader in CollectionService:GetTagged("AudioFader") do
		if fader:GetAttribute("_category") == settingKey then
			(fader :: AudioFader).Volume = volume
		end
	end
end

--- 设置指定分类的音量（0-1）
function VolumeManager.set(settingKey: string, volume: number)
	local clamped = math.clamp(volume, 0, 1)
	settings[settingKey] = clamped
	applyVolume(settingKey, clamped)
end

--- 获取指定分类的当前音量（0-1）
function VolumeManager.get(settingKey: string): number
	return settings[settingKey] or 0.5
end

--- 从 PlayerData 存档初始化所有音频通道（value 为 0-100 百分比）
function VolumeManager.initFromSettings(audioSettings: { [string]: number })
	for key, percent in audioSettings do
		if settings[key] ~= nil and typeof(percent) == "number" then
			VolumeManager.set(key, math.clamp(percent, 0, 100) / 100)
		end
	end
end

--- 客户端启动：从 PlayerData 恢复音量设置
function VolumeManager.start()
	local RunService = game:GetService("RunService")
	if not RunService:IsClient() then
		return
	end

	local PlayerDataClient = require(ReplicatedStorage.ReplicatedCode.Framework.DataStore.PlayerDataClient)
	local PlayerDataKey = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.PlayerDataKey)

	PlayerDataClient.start()

	-- 先应用内置默认值，避免等待存档期间音量为 100%
	for key, volume in settings do
		applyVolume(key, volume)
	end

	local function applySaved()
		if not PlayerDataClient.hasLoaded() then
			return
		end
		local setting = PlayerDataClient.get(PlayerDataKey.Setting)
		if type(setting) == "table" then
			VolumeManager.initFromSettings(setting)
		end
	end

	if PlayerDataClient.hasLoaded() then
		applySaved()
	else
		PlayerDataClient.loaded:Connect(applySaved)
	end

	PlayerDataClient.getUpdateSignal(PlayerDataKey.Setting):Connect(function(setting: { [string]: number })
		if type(setting) == "table" then
			VolumeManager.initFromSettings(setting)
		end
	end)
end

return VolumeManager
