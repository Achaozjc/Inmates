--!strict

--[[
	DataStoreWrapper 的元封装，提供会话锁定功能

	使用时，DataStore 密钥由会话 "拥有"，并且一次只能由一个会话 "拥有"。这意味着当服务器首次加载键时
	服务器将在密钥上设置元数据，以标记当前正在使用该密钥。其他服务器随后加载或更新该密钥的任何尝试
	更新此键的尝试都将失败，直到原始服务器使用 "unlockAfter "锁设置放弃控制权。数据存储键上的锁
	上的锁需要通过持续更新来主动维护，如果不这样做，锁将在过期时间后失效。

	当玩家在旧服务器完成数据保存之前加入新服务器时，会话锁定对避免玩家数据中的竞赛条件特别有用。
	当玩家在旧服务器完成数据保存之前加入新服务器时，会话锁定尤其有用。
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")



local noYield = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Common.NoYield)
local TableUtils = require(ReplicatedStorage.ReplicatedCode.Framework.DataStore.DataTableUtils)
local DataStoreWrapper = require(ServerScriptService.ServerCode.Framework.DataStore.Modules.DataStoreWrapper)
local mergeArraysUniqueOnly = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Common.MergeArraysUniqueOnly)


local DEFAULT_LOCK_SETTINGS = {
	expiryTime = 360,
	overwriteLock = false,
	unlockAfter = false,
}

local DATA_STORE_REQUEST_COOLDOWN_CONSTANT = 5
local DATA_STORE_REQUEST_COOLDOWN_EXPONENT = 5
local DATA_STORE_REQUEST_ATTEMPTS = 3
local NIL_STRING_PLACEHOLDER = "<nil>"

type TransformCallback = (any, DataStoreKeyInfo) -> (any, { number }?, { [string]: any }?)
type LockSettings = {
	expiryTime: number,
	overwriteLock: boolean?,
	unlockAfter: boolean?,
}

local SessionLockedDataStoreWrapper = {}
SessionLockedDataStoreWrapper.__index = SessionLockedDataStoreWrapper
SessionLockedDataStoreWrapper.sessionLockErrorString = "SessionLockError"

export type ClassType = typeof(setmetatable(
	{} :: {
		_name: string,
		_baseWrapper: DataStoreWrapper.ClassType,
		_lockedKeysLastUpdated: { [string]: number },
		_activeLockIds: { [string]: string },
	},
	SessionLockedDataStoreWrapper
	))

function SessionLockedDataStoreWrapper.new(
	name: string,
	maxAttempts: number?,
	retryConstant: number?,
	retryExponent: number?
): ClassType
	maxAttempts = maxAttempts or DATA_STORE_REQUEST_ATTEMPTS
	retryConstant = retryConstant or DATA_STORE_REQUEST_COOLDOWN_CONSTANT
	retryExponent = retryExponent or DATA_STORE_REQUEST_COOLDOWN_EXPONENT

	local self = {
		_name = name,
		_baseWrapper = DataStoreWrapper.new(name, maxAttempts, retryConstant, retryExponent),
		_lockedKeysLastUpdated = {},
		_activeLockIds = {},
	}

	setmetatable(self, SessionLockedDataStoreWrapper)

	return self
end

-- Uses the keyInfo provided in the DataStore:UpdateAsync callback to determine if the
-- key is safe to update given the wrapper's knowledge of locks it maintains and the
-- lockSettings
-- 使用 DataStore:UpdateAsync 回调中提供的 keyInfo 来确定
-- 根据包装器对其维护的锁的了解以及
-- 锁定设置
function SessionLockedDataStoreWrapper._isKeySafeToUpdate(
	self: ClassType,
	key: string,
	lockSettings: LockSettings,
	optionalKeyInfo: DataStoreKeyInfo?
): boolean
	-- If there is no metadata, the key has never been written to and is safe to access
	-- 如果没有元数据，则密钥从未被写入，可以安全访问
	if not optionalKeyInfo then
		return true
	end

	local keyInfo = optionalKeyInfo :: DataStoreKeyInfo
	local metadata: { [string]: any } = keyInfo:GetMetadata()

	if self._activeLockIds[key] then
		-- If this server has locked this key, we need to verify the lock is still in place
		-- 如果服务器锁定了这把钥匙，我们需要验证锁是否还在原处
		if self._activeLockIds[key] ~= metadata.lockId then
			-- Not safe to update. This server had a lock on this key, but this lock was evicted by another server.
			-- This could be due to developer error (not updating the key frequently enough) or due to an outage in
			-- DataStoreService or the game server. If we were to proceed with updating the key here we could be overwriting
			-- newer data.
			-- 更新不安全。此服务器曾锁定此密钥，但此锁定已被其他服务器驱逐。
			-- 这可能是由于开发者的错误（没有足够频繁地更新密钥），也可能是由于
			-- DataStoreService 或游戏服务器出现故障。如果我们在这里继续更新密钥，可能会覆盖
			-- 更新的数据。
			return false
		end
	elseif metadata.lockId then
		-- Locked keys should be refreshed regularly, if the key hasn't been updated in some time
		-- we can assume the server with the active session is finished but has failed to unlock (crashed, or bad implementation)
		-- 锁定的密钥应该定期刷新，如果密钥有一段时间没有更新的话
		-- 我们可以假设活动会话的服务器已经结束，但未能解锁（崩溃或执行不良）
		if os.difftime(os.time(), keyInfo.UpdatedTime / 1000) > lockSettings.expiryTime then
			-- Safe to update. There is a lock on this key, but it has expired.
			-- 安全更新。此密钥有锁，但已过期。
			return true
		else
			-- Not safe to update. Another sever has placed a lock on this key, and this lock has not expired.
			-- 更新不安全。另一服务器已对该密钥上锁，且该锁尚未过期。
			return false
		end
	end

	-- Safe to proceed. No lock is present on the key and this server has not had its own lock evicted.
	-- 可以安全继续。密钥上没有锁，且该服务器尚未驱逐自己的锁。
	return true
end

-- Appends to a DataStore key metadata table a unique lock identifier
-- 在数据存储键元数据表中附加唯一的锁标识符
function SessionLockedDataStoreWrapper._lockMetadata(
	self: ClassType,
	key: string,
	metadata: { [any]: any }
): { [any]: any }
	local existingLockId = self._activeLockIds[key]

	-- We only need to generate a new lock identifier if it hasn't already been set
	-- 我们只需要生成一个新的锁标识符，如果它还没有被设置的话
	if not metadata.lockId or metadata.lockId ~= existingLockId then
		return TableUtils.merge(metadata, { lockId = HttpService:GenerateGUID() })
	end

	return metadata
end

-- Removes the lock identifier from the metadata table
-- 从元数据表中删除锁定标识符
function SessionLockedDataStoreWrapper._unlockMetadata(self: ClassType, metadata: { [any]: any }): { [any]: any }
	return TableUtils.merge(metadata, { lockId = TableUtils.NoValue })
end

-- All DataStore requests in SessionLockedDataStoreWrapper are routed via _requestAsync
-- SessionLockedDataStoreWrapper 中的所有数据存储请求都通过 _requestAsync 路由
function SessionLockedDataStoreWrapper._requestAsync(
	self: ClassType,
	key: string,
	transformCallback: TransformCallback,
	optionalLockSettings: LockSettings?
): (boolean, string | any, DataStoreKeyInfo?)
	local lockSettings = TableUtils.merge(DEFAULT_LOCK_SETTINGS, optionalLockSettings) :: LockSettings
	local lockTime = os.clock()

	local keyWasSafeToUpdate = true

	-- Session locking requires _everything_ is routed through UpdateAsync calls so that the key can be
	-- read AND written atomically. This allows us to verify the key is safe to write to, and write to it
	-- at the same time.
	-- 会话锁定要求通过 UpdateAsync 调用路由_everything_，以便键可以
	-- 原子地读取和写入。这样，我们就可以验证密钥是否可以安全写入，并同时写入它
	-- 同时写入。
	local success, result: any, keyInfo = self._baseWrapper:updateAsync(
		key,
		function(currentValue: any, currentKeyInfo: DataStoreKeyInfo?)
			-- If the key is deemed 'unsafe' to write to, we only want to proceed when lockSettings.overwriteLock is true
			-- 如果键被认为是 "不安全 "的，我们只希望在 lockSettings.overwriteLock 为 true 时才继续写入
			if not self:_isKeySafeToUpdate(key, lockSettings, currentKeyInfo) and not lockSettings.overwriteLock then
				keyWasSafeToUpdate = false
				return nil
			end

			-- Substitute stand-ins for nil with an actual nil value (see comment below)
			-- 用实际的 nil 值代替 nil 的替身（见下面的注释）
			if currentValue == NIL_STRING_PLACEHOLDER then
				currentValue = nil
			end

			-- To prevent race conditions we do not allow transformCallback to yield
			-- 为防止出现竞赛条件，我们不允许 transformCallback 产生
			local value, userIds, metadata = noYield(transformCallback, currentValue, currentKeyInfo)
			metadata = metadata or {}

			-- We cannot return nil or the key metadata will not be updated, so instead we will use a stand-in
			-- string that we will substitute for nil later
			-- 我们不能返回 nil，否则键元数据将不会被更新，因此我们将使用一个替身
			-- 字符串来代替 nil
			if value == nil then
				value = NIL_STRING_PLACEHOLDER
			end

			-- We want to release our lock on the key if lockSettings.unlockAfter is true, or ensure it is in place
			-- if it is not
			-- 如果 lockSettings.unlockAfter 为 true，我们要释放对钥匙的锁定，或者确保锁定到位
			-- 如果不是
			if lockSettings.unlockAfter then
				metadata = self:_unlockMetadata(metadata)
			else
				metadata = self:_lockMetadata(key, metadata)
			end

			return value, userIds, metadata
		end,
		-- DataStoreWrapper allows us to include a custom handler that will be used to call the
		-- DataStore function in place of pcall. We need that here so we can still retry if the
		-- DataStore operation worked but the key was not safe to update
		-- DataStoreWrapper 允许我们包含一个自定义处理程序，用来调用
		-- DataStore 函数来代替 pcall。我们在此需要它，以便在
		-- DataStore 操作成功，但密钥更新不安全时，我们仍可重试
		function(operation)
			local operationSuccess, operationResult, operationKeyInfo = pcall(operation)

			if not keyWasSafeToUpdate then
				operationSuccess = false
				operationResult = self.sessionLockErrorString
			end

			return operationSuccess, operationResult, operationKeyInfo
		end
	)

	if success then
		-- Substitute nil stand-in for actual nil value (see comment above)
		-- 用 nil 代替实际的 nil 值（见上文注释）
		if result == NIL_STRING_PLACEHOLDER then
			result = nil
		end

		local metadata = if keyInfo then keyInfo:GetMetadata() else nil
		local lockId = if metadata then metadata.lockId else nil

		if lockId then
			self:_storeLock(key, lockId, lockTime, lockSettings)
		else
			self:_forgetLock(key)
		end
	else
		-- We will surface a unique error string for session lock errors so the player can be shown a distinct message
		-- The raw error value from an error thrown in the transform function of UpdateAsync is not passed, so instead we
		-- will search for it in the errorMessage. This is brittle and vulnerable for how Roblox changes the errorMessage
		-- DataStore:UpdateAsync returns when the transform function errors.
		-- 我们将为会话锁定错误提供一个唯一的错误字符串，以便向玩家显示一条不同的消息
		-- UpdateAsync 的转换函数中抛出的错误所产生的原始错误值不会被传递，因此我们
		-- 我们将在 errorMessage 中搜索它。对于 Roblox 如何更改 errorMessage 而言，这种方法既脆弱又易受攻击
		-- 当转换函数出错时，DataStore:UpdateAsync 会返回错误信息。
		if string.find(tostring(result), self.sessionLockErrorString) then
			result = self.sessionLockErrorString
		end
	end

	return success, result, keyInfo
end

-- Store a record of the lock in memory so we can detect cases when a lock this server
-- has placed has been removed when updating a key
-- 在内存中存储锁的记录，这样我们就能在更新键时检测到本服务器
-- 已设置的锁在更新密钥时被移除的情况
function SessionLockedDataStoreWrapper._storeLock(
	self: ClassType,
	key: string,
	lockId: string,
	lockTime: number,
	lockSettings: LockSettings
)
	self._activeLockIds[key] = lockId

	self:_warnIfLockNotMaintained(key, lockId, lockTime, lockSettings)
end

-- Schedule a warning if the lock has not been removed or updated before its due to expire as this should
-- almost always be avoided in production code
-- 如果锁在到期前没有被移除或更新，则会发出警告，因为这应该
-- 在生产代码中几乎总是应该避免
function SessionLockedDataStoreWrapper._warnIfLockNotMaintained(
	self: ClassType,
	key: string,
	lockId: string,
	lockTime: number,
	lockSettings: LockSettings
)
	self._lockedKeysLastUpdated[key] = lockTime	
	task.delay(lockSettings.expiryTime, function()
		if not self._activeLockIds[key] or self._activeLockIds[key] ~= lockId then
			-- If we have already removed this lock or replaced it with another one, we do not need to warn
			-- 如果我们已经移除了这把锁或用另一把锁替换了它，则无需发出警告
			return
		end

		if self._lockedKeysLastUpdated[key] and self._lockedKeysLastUpdated[key] == lockTime then
			warn(
				string.format(
					"Key %s in DataStore %s was locked but not explicitly unlocked or the lock refreshed within the expiryTime.",
					key,
					self._name
				)
			)
		end
	end)
end

-- Remove a key's lock identifier and updated time from memory
-- 从内存中删除钥匙的锁定标识符和更新时间
function SessionLockedDataStoreWrapper._forgetLock(self: ClassType, key: string)
	self._lockedKeysLastUpdated[key] = nil
	self._activeLockIds[key] = nil
end

function SessionLockedDataStoreWrapper.updateAsync(
	self: ClassType,
	key: string,
	transformCallback: TransformCallback,
	lockSettings: LockSettings?
): (boolean, string | any)
	return self:_requestAsync(key, transformCallback, lockSettings)
end

-- Refreshes the lock this server has on a key by updating the key without changing its value
-- This should be called every lockSettings.expiryTime seconds unless another request is made
-- 通过更新密钥而不改变其值，刷新该服务器对密钥的锁定。
-- 除非有其他请求，否则应每隔 lockSettings.expiryTime 秒调用一次
function SessionLockedDataStoreWrapper.refreshLockAsync(self: ClassType, key: string): (boolean, string?)
	return self:_requestAsync(key, function(value: any, keyInfo: DataStoreKeyInfo)
		local userIds = if keyInfo then keyInfo:GetUserIds() else nil
		local metadata = if keyInfo then keyInfo:GetMetadata() else nil

		return value, userIds, metadata
	end)
end

function SessionLockedDataStoreWrapper.getAsync(
	self: ClassType,
	key: string,
	lockSettings: LockSettings?,
	userIdsToInclude: { number }?
): (boolean, any | string, DataStoreKeyInfo?)
	return self:_requestAsync(key, function(value: any, keyInfo: DataStoreKeyInfo)
		local userIds = if keyInfo then keyInfo:GetUserIds() else nil
		local metadata = if keyInfo then keyInfo:GetMetadata() else nil

		-- Although this is a get request, as this get actually saves, we need to make sure we
		-- are writing to the userIds list for compliance reasons
		-- 虽然这是一个获取请求，但由于这个获取请求实际上是在保存，我们需要确保我们
		-- 写入 userIds 列表，以符合要求
		local oldUserIds = userIds or {}

		if userIdsToInclude then
			userIds = mergeArraysUniqueOnly(oldUserIds :: { number }, userIdsToInclude)
		end

		return value, userIds, metadata
	end, lockSettings)
end

function SessionLockedDataStoreWrapper.setAsync(
	self: ClassType,
	key: string,
	value: any,
	userIds: { number }?,
	options: DataStoreSetOptions?,
	lockSettings: LockSettings?
): (boolean, string?)
	return self:_requestAsync(key, function()
		local metadata = if options then options:GetMetadata() else nil

		return value, userIds, metadata
	end, lockSettings)
end

function SessionLockedDataStoreWrapper.areAllQueuesEmpty(self: ClassType): boolean
	return self._baseWrapper:areAllQueuesEmpty()
end

function SessionLockedDataStoreWrapper.getQueueLength(self: ClassType, key: string): number
	return self._baseWrapper:getQueueLength(key)
end

-- See caveat comment in DataStoreWrapper:skipAllQueuesToLastEnqueued()
-- 参见 DataStoreWrapper:skipAllQueuesToLastEnqueued() 中的注意事项注释
function SessionLockedDataStoreWrapper.skipAllQueuesToLastEnqueued(self: ClassType)
	self._baseWrapper:skipAllQueuesToLastEnqueued()
end

return SessionLockedDataStoreWrapper

