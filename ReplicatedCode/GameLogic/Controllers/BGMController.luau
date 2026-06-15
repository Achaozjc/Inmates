--!strict

--[[
	BGMController（移植自 spicy 项目，简化版）
	·  循环交替播放 SoundEnum.BGM 中的背景音乐：
	   第一首结束播第二首，最后一首结束回到第一首。
	·  优先复用 Studio 预置的 SoundService/bgm/music，没有则运行时创建。
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local GameLogic = ReplicatedStorage.ReplicatedCode.GameLogic

local SoundEnum = require(GameLogic.Shared.Enums.SoundEnum)

local BGMController = {}

local _sound: Sound? = nil
local _trackIndex: number = 0

-- 获取（或创建）用于播放 BGM 的 Sound 实例
local function getOrCreateSound(): Sound
	local bgmFolder = SoundService:FindFirstChild("bgm")
	if not bgmFolder then
		bgmFolder = Instance.new("Folder")
		bgmFolder.Name = "bgm"
		bgmFolder.Parent = SoundService
	end

	local sound = bgmFolder:FindFirstChild("music")
	if not sound or not sound:IsA("Sound") then
		sound = Instance.new("Sound")
		sound.Name = "music"
		sound.Parent = bgmFolder
	end
	return sound :: Sound
end

-- 播放当前 _trackIndex 指向的曲目
local function playCurrentTrack()
	local sound = _sound
	if not sound then
		return
	end
	local assetId = SoundEnum.BGM[_trackIndex]
	if not assetId then
		return
	end
	sound.SoundId = "rbxassetid://" .. tostring(assetId)
	sound:Play()
end

-- 切换到下一首（在播放列表中循环）
local function playNextTrack()
	if #SoundEnum.BGM == 0 then
		return
	end
	_trackIndex = (_trackIndex % #SoundEnum.BGM) + 1
	playCurrentTrack()
end

function BGMController.start()
	if #SoundEnum.BGM == 0 then
		return
	end

	local sound = getOrCreateSound()
	sound.Looped = false
	_sound = sound

	-- 一首结束后自动播放下一首，实现循环交替
	sound.Ended:Connect(function()
		playNextTrack()
	end)

	playNextTrack()
end

return BGMController
