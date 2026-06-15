--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

--[[
	模块: PlayerDataClient
	描述: 玩家数据客户端组件
	职责:
		1. 接收服务端同步的数据
		2. 提供数据读取 API
		3. 提供数据变更的信号 (Signal)
--]]

local Framework = ReplicatedStorage:WaitForChild("ReplicatedCode"):WaitForChild("Framework")
local TableUtils = require(Framework.DataStore.DataTableUtils)
local Signal = require(Framework.Packages.Signal)
local PlayerDataErrorType = require(Framework.DataStore.PlayerDataErrorType)
local Network = require(Framework.Core.Network)
local RemoteEventName = require(ReplicatedStorage.ReplicatedCode.Framework.Core.Network.RemoteName.RemoteEventName)
local t = Network.t

type PlayerData = { [string]: any }

local PlayerDataClient = {}
PlayerDataClient._data = {} :: PlayerData
PlayerDataClient._loadErrorType = nil :: string?
PlayerDataClient._saveErrorType = nil :: string?
PlayerDataClient._hasLoaded = false

-- Signals
PlayerDataClient.loaded = Signal.new()
PlayerDataClient.updated = Signal.new()
PlayerDataClient.saved = Signal.new()
PlayerDataClient.error = Signal.new()
PlayerDataClient._valueSignals = {} :: {[string]: any} -- 缓存每个 Key 的信号

function PlayerDataClient.start()
	assert(RunService:IsClient(), "PlayerDataClient can only be started on the client")
	PlayerDataClient._listenForEvents()
end

-- 状态查询 API

function PlayerDataClient.hasLoadingErrored(): boolean
	return PlayerDataClient._loadErrorType ~= nil
end

function PlayerDataClient.hasSavingErrored(): boolean
	return PlayerDataClient._saveErrorType ~= nil
end

function PlayerDataClient.getLoadError(): string?
	return PlayerDataClient._loadErrorType
end

function PlayerDataClient.getSaveError(): string?
	return PlayerDataClient._saveErrorType
end

function PlayerDataClient.hasLoaded(): boolean
	return PlayerDataClient._hasLoaded
end

-- 数据读取 API

function PlayerDataClient.get(valueName: string): any
	assert(PlayerDataClient._hasLoaded, "The player's data is still loading")

	local value = PlayerDataClient._data[valueName]
	
	if typeof(value) == "table" then
		value = TableUtils.deepCopy(value)
	end

	return value
end

-- 获取特定 Key 的信号，用于精准监听数据变化
function PlayerDataClient.getUpdateSignal(valueName: string)
	if not PlayerDataClient._valueSignals[valueName] then
		PlayerDataClient._valueSignals[valueName] = Signal.new()
	end
	return PlayerDataClient._valueSignals[valueName]
end

-- 内部事件处理

function PlayerDataClient._onDataLoaded(data: PlayerData, success: boolean, errorType: string?)
	PlayerDataClient._data = data
	PlayerDataClient._loadErrorType = errorType
	PlayerDataClient._hasLoaded = true

	PlayerDataClient.loaded:Fire(success, errorType)

	-- 如果加载失败，同时触发 error 信号，方便上层统一监听错误状态
	if not success and errorType ~= nil then
		PlayerDataClient.error:Fire(errorType)
	end
end

function PlayerDataClient._onDataUpdated(valueName: string, value: any)
	PlayerDataClient._data[valueName] = value

	-- 触发特定 Key 的信号
	if PlayerDataClient._valueSignals[valueName] then
		-- 同样需要深拷贝，防止回调中修改
		local signalValue = value
		if typeof(value) == "table" then
			signalValue = TableUtils.deepCopy(value)
		end
		PlayerDataClient._valueSignals[valueName]:Fire(signalValue)
	end
	
	-- 触发通用更新信号
	local updateValue = value
	if typeof(value) == "table" then
		updateValue = TableUtils.deepCopy(value)
	end
	PlayerDataClient.updated:Fire(valueName, updateValue)
end

function PlayerDataClient._onDataSaved(success: boolean, errorType: string?)
	PlayerDataClient._saveErrorType = errorType
	PlayerDataClient.saved:Fire(success, errorType)
end

function PlayerDataClient._listenForEvents()
	Network.connectEvent(RemoteEventName.PlayerDataLoaded,
		function(data: PlayerData, success: boolean, errorType: PlayerDataErrorType.EnumType?)
			PlayerDataClient._onDataLoaded(data, success, errorType)
		end)

	Network.connectEvent(RemoteEventName.PlayerDataUpdated, 
		function(valueName: string, value: any)
			PlayerDataClient._onDataUpdated(valueName, value)
		end)

	Network.connectEvent(RemoteEventName.PlayerDataSaved,
		function(success: boolean, errorType: PlayerDataErrorType.EnumType?)
			PlayerDataClient._onDataSaved(success, errorType)
		end)
end

return PlayerDataClient
