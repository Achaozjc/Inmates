--!strict
--[[
	VolumeManager — 统一音量管理入口
	通过 AudioFader（新 Audio API 总线）和 ReplicatedStorage 属性（响应式）控制音量
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VolumeManager = {}

-- 内部缓存（0-1）
local settings: { [string]: number } = {
	s_sfx = 0.5,
	s_bgm = 0.5,
	s_ambient = 0.5,
	s_world = 0.5,
}

-- 更新单个分类的所有音量通道
local function applyVolume(settingKey: string, volume: number)
	-- 1. ReplicatedStorage 属性（供 AudioPlayer 组件等响应式监听）
	ReplicatedStorage:SetAttribute(settingKey, volume)

	-- 2. AudioFader（按 _category 属性匹配）
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

--- 从 PlayerData 存档初始化所有音频通道（value 已为 0-1）
function VolumeManager.initFromSettings(audioSettings: { [string]: number })
	for key, volume in audioSettings do
		if settings[key] ~= nil then
			VolumeManager.set(key, volume)
		end
	end
end

return VolumeManager
