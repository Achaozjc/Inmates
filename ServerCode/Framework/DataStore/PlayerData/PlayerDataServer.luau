--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

--[[
	模块: PlayerDataServer
	描述: 玩家数据持久化核心服务
	职责:
		1. 管理玩家数据的加载、保存和自动保存
		2. 处理数据版本迁移 (Reconciliation)
		3. 提供数据读写 API
		4. 与客户端同步数据状态
	
	优化:
		- 移除冗余代码和注释
		- 增强类型安全
		- 优化保存逻辑和错误处理
--]]

local Framework = ReplicatedStorage:WaitForChild("ReplicatedCode"):WaitForChild("Framework")
local Utility = Framework:WaitForChild("Utility")
local Packages = Framework:WaitForChild("Packages")

local noYield = require(Utility.Common.NoYield)
local Signal = require(Packages.Signal)
local DataStoreWrapper = require(ServerScriptService.ServerCode.Framework.DataStore.Modules.DataStoreWrapper)
local setInterval = require(Utility.Time.SetInterval)
local safePlayerAdded = require(Utility.Player.SafePlayerAdded)
local getMaxRequestTime = require(ServerScriptService.ServerCode.Framework.DataStore.Modules.getMaxRequestTime)
local PlayerDataErrorType = require(ReplicatedStorage.ReplicatedCode.Framework.DataStore.PlayerDataErrorType)
local TableUtils = require(ReplicatedStorage.ReplicatedCode.Framework.DataStore.DataTableUtils)
local Network = require(ReplicatedStorage.ReplicatedCode.Framework.Core.Network)
local RemoteEventName = require(ReplicatedStorage.ReplicatedCode.Framework.Core.Network.RemoteName.RemoteEventName)

-- 配置常量
local ALLOW_STUDIO_ACCESS = false -- 是否允许 Studio 访问真实数据
local AUTO_SAVE_INTERVAL = 300 -- 自动保存间隔（秒）
local DATA_STORE_REQUEST_ATTEMPTS = 6
local DATA_STORE_REQUEST_COOLDOWN_CONSTANT = 2
local DATA_STORE_REQUEST_COOLDOWN_EXPONENT = 2
local DEFAULT_DATA_STORE_NAME = "PlayerData_v1"
local BEFORE_LOAD_WARN_INTERVAL = 60

-- 类型定义
export type PlayerData = { [string]: any }
type Metadata = { [string]: any }

-- Studio 环境检查
local dataStoresEnabled = true
local isStudio = RunService:IsStudio()
if RunService:IsStudio() then
	if game.PlaceId == 0 or not ALLOW_STUDIO_ACCESS then
		warn("[PlayerDataServer] DataStores disabled: Place unpublished or ALLOW_STUDIO_ACCESS is false.")
		dataStoresEnabled = false
	end
end

-- 性能警告检查
local maxRequestTime = getMaxRequestTime(
	DATA_STORE_REQUEST_ATTEMPTS,
	DATA_STORE_REQUEST_COOLDOWN_CONSTANT,
	DATA_STORE_REQUEST_COOLDOWN_EXPONENT
)
if maxRequestTime > AUTO_SAVE_INTERVAL then
	warn(string.format(
		"[PlayerDataServer] AUTO_SAVE_INTERVAL (%d) may be insufficient for max retry time (%.2f)",
		AUTO_SAVE_INTERVAL,
		maxRequestTime
	))
end

local PlayerDataServer = {}
PlayerDataServer.playerDataUpdated = Signal.new()

-- 私有状态
local _playerDataLoadErrors: { [Player]: string } = {}
local _threadsPendingPlayerDataLoad: { [Player]: { thread } } = {}
local _playerData: { [Player]: PlayerData } = {}
local _playerDataSynced: { [Player]: PlayerData } = {} -- 记录上次保存/加载的数据，用于差异对比
local _playerDataMetadata: { [Player]: Metadata } = {}
local _privateValueNames: { [string]: boolean } = {} -- 不会同步给客户端的字段
local _baseWrapper: any = nil
local _started = false
local _beforeLoadWarnTimes: { [Player]: { [string]: number } } = {}
local _defaultPlayerData: any = nil -- 由 start(defaultDataModule) 注入，需提供 Reconcile、GetDefaultData

-- 在首次向客户端下发 PlayerDataLoaded 之前执行（可改写内存中的 _playerData，合并进首包）
local _beforeSendLoadedDataListeners: { (Player) -> () } = {}

--========================================
-- Public API
--========================================

local function warnBeforeLoad(player: Player, apiName: string, valueName: string)
	local warningKey = apiName .. ":" .. valueName
	local now = os.clock()
	local playerWarnTimes = _beforeLoadWarnTimes[player]
	if not playerWarnTimes then
		playerWarnTimes = {}
		_beforeLoadWarnTimes[player] = playerWarnTimes
	end

	local lastWarnAt = playerWarnTimes[warningKey]
	if lastWarnAt and now - lastWarnAt < BEFORE_LOAD_WARN_INTERVAL then
		return
	end

	playerWarnTimes[warningKey] = now
	--warn(
	--	string.format(
	--		"[PlayerDataServer] %s called before load for player: %s valueName: %s",
	--		apiName,
	--		tostring(player.UserId),
	--		tostring(valueName)
	--	)
	--)
end

local function clearPlayerState(player: Player)
	_playerData[player] = nil
	_playerDataSynced[player] = nil
	_playerDataLoadErrors[player] = nil
	_playerDataMetadata[player] = nil
	_threadsPendingPlayerDataLoad[player] = nil
	_beforeLoadWarnTimes[player] = nil
end

function PlayerDataServer.registerBeforeSendLoadedData(listener: (Player) -> ())
	table.insert(_beforeSendLoadedDataListeners, listener)
end

function PlayerDataServer.start(dataStoreName: string?, privateValueNames: { string }?, defaultPlayerDataModule: any?)
	assert(not _started, "PlayerDataServer has already been started")
	assert(defaultPlayerDataModule and defaultPlayerDataModule.Reconcile and defaultPlayerDataModule.GetDefaultData, "PlayerDataServer.start: defaultPlayerDataModule (Reconcile, GetDefaultData) required")
	_started = true
	_defaultPlayerData = defaultPlayerDataModule

	local storeName = dataStoreName or DEFAULT_DATA_STORE_NAME
	
	_baseWrapper = DataStoreWrapper.new(
		storeName,
		DATA_STORE_REQUEST_ATTEMPTS,
		DATA_STORE_REQUEST_COOLDOWN_CONSTANT,
		DATA_STORE_REQUEST_COOLDOWN_EXPONENT
	)

	if privateValueNames then
		_privateValueNames = TableUtils.invertValuesToKeys(privateValueNames)
	end

	PlayerDataServer._listenForPlayers()
	PlayerDataServer._bindSavingToGameClose()
	PlayerDataServer._startAutoSaveLoop()
	
	if isStudio then
		print(string.format("[PlayerDataServer] Started using DataStore: %s", storeName))
	end
end

-- 检查数据是否已加载
function PlayerDataServer.hasLoaded(player: Player): boolean
	return _playerData[player] ~= nil
end

-- 检查是否正在加载
function PlayerDataServer.isLoading(player: Player): boolean
	return _threadsPendingPlayerDataLoad[player] ~= nil
end

-- 检查是否加载出错
function PlayerDataServer.hasErrored(player: Player): boolean
	return _playerDataLoadErrors[player] ~= nil
end

-- 设置字段为私有（不自动同步给客户端）
function PlayerDataServer.setValueAsPrivate(valueName: string, isPrivate: boolean)
	_privateValueNames[valueName] = isPrivate
end

-- 挂起当前线程直到玩家数据加载完成
function PlayerDataServer.waitForDataLoadAsync(player: Player)
	if PlayerDataServer.hasLoaded(player) then
		return
	end
	
	if not _threadsPendingPlayerDataLoad[player] then
		_threadsPendingPlayerDataLoad[player] = {}
	end

	table.insert(_threadsPendingPlayerDataLoad[player], coroutine.running())
	coroutine.yield()
end

-- 获取数据值
-- @param syncedValueOnly: 是否只获取上次同步/保存的值（用于验证）
function PlayerDataServer.getOfflineDataAsync(userId: number): any
	local key = tostring(userId)
	local success, result = _baseWrapper:getAsync(key)
	if success then
		return result
	end
	return nil
end

function PlayerDataServer.getValue(player: Player, valueName: string, syncedValueOnly: boolean?): any
	if not PlayerDataServer.hasLoaded(player) then
		warnBeforeLoad(player, "getValue", valueName)
		return nil
	end

	local value
	if syncedValueOnly then
		value = _playerDataSynced[player][valueName]
	else
		value = _playerData[player][valueName]
	end

	-- 深度拷贝防止外部修改内部状态
	if typeof(value) == "table" then
		value = TableUtils.deepCopy(value)
	end

	return value
end

-- 设置数据值
function PlayerDataServer.setValue(player: Player, valueName: string, value: any)
	assert(PlayerDataServer.hasLoaded(player), "Player data not loaded")

	if typeof(value) == "table" then
		value = TableUtils.deepCopy(value)
	end

	_playerData[player][valueName] = value

	-- 如果不是私有字段，同步给客户端
	if not _privateValueNames[valueName] then
		Network.fireClient(RemoteEventName.PlayerDataUpdated, player, valueName, value)
	end

	PlayerDataServer.playerDataUpdated:Fire(player, valueName, value)
end

-- 更新数据值 (支持变换函数)
function PlayerDataServer.updateValue(player: Player, valueName: string, transformFunction: (any) -> any)
	if not PlayerDataServer.hasLoaded(player) then
		warnBeforeLoad(player, "updateValue", valueName)
		return
	end

	local oldValue = PlayerDataServer.getValue(player, valueName)
	-- 禁止在变换函数中 Yield
	local newValue = noYield(transformFunction, oldValue)

	if newValue ~= nil then
		PlayerDataServer.setValue(player, valueName, newValue)
	end
end

-- 移除数据值
function PlayerDataServer.removeValue(player: Player, valueName: string)
	assert(PlayerDataServer.hasLoaded(player), "Player data not loaded")
	
	local oldValue = PlayerDataServer.getValue(player, valueName)
	PlayerDataServer.setValue(player, valueName, nil)
	return oldValue
end

-- 设置 DataStore 元数据
function PlayerDataServer.setMetaData(player: Player, metadata: Metadata)
	assert(PlayerDataServer.hasLoaded(player), "Player data not loaded")
	_playerDataMetadata[player] = TableUtils.deepCopy(metadata)
end

-- 强制保存数据
function PlayerDataServer.saveDataAsync(player: Player)
	assert(PlayerDataServer.canSave(player), "Cannot save player data currently")
	local data = _playerData[player]
	return PlayerDataServer._savePlayerDataAsync(player, data)
end

-- 检查是否可以保存
function PlayerDataServer.canSave(player: Player): boolean
	if not dataStoresEnabled then return false end
	if not PlayerDataServer.hasLoaded(player) then return false end
	if PlayerDataServer.hasErrored(player) then return false end
	return true
end

--========================================
-- Internal Methods
--========================================

function PlayerDataServer._listenForPlayers()
	safePlayerAdded(function(newPlayer: Player)
		PlayerDataServer._onPlayerAddedAsync(newPlayer)
	end)
end

function PlayerDataServer._getKey(player: Player)
	return tostring(player.UserId)
end

function PlayerDataServer._onPlayerAddedAsync(player: Player, retryCount: number?)
	local hasErrored = false
	local errorType = PlayerDataErrorType.DataStoreError

	if dataStoresEnabled then
		local key = PlayerDataServer._getKey(player)
		local success, result = _baseWrapper:getAsync(key)

		if not player:IsDescendantOf(Players) then
			clearPlayerState(player)
			return
		end

		if success then
			-- 数据协调：合并默认数据与已保存数据
			_playerData[player] = result and _defaultPlayerData.Reconcile(result)
				or TableUtils.deepCopy(_defaultPlayerData.GetDefaultData(player.UserId))
			
			_playerDataSynced[player] = TableUtils.deepCopy(_playerData[player])
		else
			warn(string.format("[PlayerDataServer] Load error for %s: %s", tostring(player.UserId), tostring(result)))
			hasErrored = true
		end
	else
		-- Studio 且禁用 DataStore 时，直接使用默认数据，并标记为错误以阻止保存
		_playerData[player] = TableUtils.deepCopy(_defaultPlayerData.GetDefaultData(player.UserId))
		hasErrored = true
	end

	if hasErrored then
		-- 重试逻辑
		if not RunService:IsStudio() and player:IsDescendantOf(Players) then
			local currentRetry = retryCount or 0
			if currentRetry < 4 then
				warn("[PlayerDataServer] Retrying load for", player.Name, "Attempt:", currentRetry + 1)
				task.wait(2 ^ currentRetry)
				PlayerDataServer._onPlayerAddedAsync(player, currentRetry + 1)
				return
			else
				player:Kick("Data load failed. Please rejoin.")
				clearPlayerState(player)
				return
			end
		end

		-- Studio 禁用 DataStore 时允许本地默认数据运行；线上加载失败会在重试耗尽后踢出。
		if _playerData[player] == nil then
			_playerData[player] = TableUtils.deepCopy(_defaultPlayerData.GetDefaultData(player.UserId))
		end
		PlayerDataServer._setPlayerDataAsErrored(player, errorType)
	else
		PlayerDataServer._sendLoadedData(player)
	end
end

function PlayerDataServer._setPlayerDataAsErrored(player: Player, errorType: string)
	_playerDataLoadErrors[player] = errorType
	PlayerDataServer._sendLoadedData(player)
end

function PlayerDataServer._sendLoadedData(player: Player)
	if not player:IsDescendantOf(Players) then
		clearPlayerState(player)
		return
	end

	-- 允许业务在首包下发前补齐字段（如引导步骤），避免出现「首包 step=0、后续 Updated 早于 GUI listen」的竞态
	for _, listener in _beforeSendLoadedDataListeners do
		listener(player)
	end

	local data = TableUtils.filter(
		(TableUtils.deepCopy(_playerData[player]) :: PlayerData),
		function(value: any, valueName: string)
			return not _privateValueNames[valueName]
		end
	) :: PlayerData
	
	local success = not PlayerDataServer.hasErrored(player)
	local errorType = _playerDataLoadErrors[player]

	-- 恢复等待加载的线程
	if _threadsPendingPlayerDataLoad[player] then
		for _, thread in ipairs(_threadsPendingPlayerDataLoad[player]) do
			task.spawn(thread)
		end
		_threadsPendingPlayerDataLoad[player] = nil
	end
	
	Network.fireClient(RemoteEventName.PlayerDataLoaded, player, data, success, errorType)
end

function PlayerDataServer.onPlayerRemovingAsync(player: Player)
	local canSave = PlayerDataServer.canSave(player)
	local data = _playerData[player]

	-- 清理内存
	clearPlayerState(player)

	if canSave and data then
		data.lastLoginTime = Workspace:GetServerTimeNow()
		PlayerDataServer._savePlayerDataAsync(player, data)
	end
end

function PlayerDataServer._getDataStoreSetOptions(player: Player): DataStoreSetOptions
	local metadata = _playerDataMetadata[player] or {}
	local setOptions = Instance.new("DataStoreSetOptions")
	setOptions:SetMetadata(metadata)
	return setOptions
end

function PlayerDataServer._savePlayerDataAsync(player: Player, data: any)
	local setOptions = PlayerDataServer._getDataStoreSetOptions(player)
	local dataSubmitted = TableUtils.deepCopy(data)

	local success, result = _baseWrapper:_setAsync(
		PlayerDataServer._getKey(player),
		dataSubmitted,
		{ player.UserId },
		setOptions
	)

	if not success then
		warn(string.format("[PlayerDataServer] Save failed for %s: %s", tostring(player.UserId), tostring(result)))
	else
		if PlayerDataServer.hasLoaded(player) then
			_playerDataSynced[player] = dataSubmitted
		end
	end

	if player:IsDescendantOf(Players) then
		local errorType
		if not success then
			errorType = PlayerDataErrorType.DataStoreError
		end
		Network.fireClient(RemoteEventName.PlayerDataSaved, player, success, errorType)
	end

	return success, result
end

-- immediateMode=true：并发触发所有保存（用于关服）；否则每人间隔 0.1s 错峰（用于自动存档）
function PlayerDataServer._saveAllPlayerData(immediateMode: boolean?)
	local index = 0
	for player, data in pairs(_playerData) do
		if PlayerDataServer.canSave(player) then
			if immediateMode then
				task.spawn(PlayerDataServer._savePlayerDataAsync, player, data)
			else
				-- 错峰：每个玩家延迟 index*0.1s，避免同时触发大量 DataStore 请求
				task.delay(index * 0.1, function()
					PlayerDataServer._savePlayerDataAsync(player, data)
				end)
			end
			index += 1
		end
	end
end

function PlayerDataServer._bindSavingToGameClose()
	if not dataStoresEnabled then return end
	
	game:BindToClose(function()
		print("[PlayerDataServer] Server closing, saving all data...")
		-- 关服时并发保存，不错峰，节省 BindToClose 的有限时间窗口
		PlayerDataServer._saveAllPlayerData(true)
		
		-- 等待所有队列处理完毕
		if _baseWrapper then
			_baseWrapper:skipAllQueuesToLastEnqueued()
			while not _baseWrapper:areAllQueuesEmpty() do
				task.wait(0.1)
			end
		end
	end)
end

function PlayerDataServer._startAutoSaveLoop()
	setInterval(function()
		PlayerDataServer._saveAllPlayerData()
		if isStudio then
			print("[PlayerDataServer] AutoSave executed")
		end
	end, AUTO_SAVE_INTERVAL)
end

return PlayerDataServer
