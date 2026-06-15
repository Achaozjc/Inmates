--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--[[
数据存储的封装程序，可实现对失败请求的自动重试。

	对同一密钥的请求会排队，并通过线程队列（包括重试）进行调度，以确保它们
	按顺序处理。这避免了 DataStore 重试实现中的一个常见缺陷，即有可能发生
	的重试可能发生在较新请求之后，导致保存的数据过时。

	DataStoreWrapper 的请求方法在请求（及其重试）完成之前都会屈服。
--]]

local DataStoreService = game:GetService("DataStoreService")

local retryAsync = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Common.RetryAsync)
local ThreadQueue = require(ReplicatedStorage.ReplicatedCode.Framework.Infrastructure.Classes.ThreadQueue)
local noYield = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Common.NoYield)

local NIL_STRING_PLACEHOLDER = "<nil>"
local RETRY_CONSTANT_SECONDS = 0
local RETRY_EXPONENT_SECONDS = 0
local MAX_ATTEMPTS = 1

type TransformCallback = (any, DataStoreKeyInfo) -> (any, { number }?, { [string]: any }?)

local dataStoreOptions = Instance.new("DataStoreOptions")
dataStoreOptions:SetExperimentalFeatures({ v2 = true })

local DataStoreWrapper = {}
DataStoreWrapper.__index = DataStoreWrapper

export type ClassType = typeof(setmetatable(
	{} :: {
		_name: string,
		_maxAttempts: number,
		_retryConstant: number,
		_retryExponent: number,
		_keyQueues: { [string]: ThreadQueue.ClassType },
		_cachedStore: GlobalDataStore?,
	},
	DataStoreWrapper
))

function DataStoreWrapper.new(
	name: string,
	maxAttempts: number?,
	retryConstant: number?,
	retryExponent: number?
): ClassType
	local self = {
		_name = name,
		_maxAttempts = maxAttempts or MAX_ATTEMPTS,
		_retryConstant = retryConstant or RETRY_CONSTANT_SECONDS,
		_retryExponent = retryExponent or RETRY_EXPONENT_SECONDS,
		_keyQueues = {},
		_cachedStore = nil :: GlobalDataStore?,
	}
	setmetatable(self, DataStoreWrapper)

	return self
end

function DataStoreWrapper._attemptAsync(
	self: ClassType,
	key: string,
	operation: (dataStore: GlobalDataStore) -> nil,
	optionalRetryFunctionHandler: retryAsync.FunctionHandler?
): (boolean, ...any)
	-- 由于我们将重试失败的请求，因此我们必须有一个队列机制来确保
	-- 每个请求都是按顺序处理的，以避免出现竞争情况（即请求 2 完成时
	-- 请求 1 正在等待重试）。ThreadQueue:submitAsync 会在任务
	-- 完成，从而允许我们异步使用 DataStoreWrapper 的 API
	local queue = self._keyQueues[key] :: typeof(ThreadQueue.new())

	if not queue then
		queue = ThreadQueue.new() :: typeof(ThreadQueue.new())
		self._keyQueues[key] = queue
	end

	--  Capture the tuple values in a table
	local queueReturnValues = {
		queue:submitAsync(function()
			return self:_onQueuePop(operation, optionalRetryFunctionHandler)
		end),
	}

	-- 删除空队列，防止内存泄漏
	if queue:getLength() == 0 then
		self._keyQueues[key] = nil
	end

	-- 返回 onQueuePop 的成功值和结果值
	return table.unpack(queueReturnValues)
end

function DataStoreWrapper._onQueuePop(
	self: ClassType,
	operation: (dataStore: GlobalDataStore) -> nil,
	optionalRetryFunctionHandler: retryAsync.FunctionHandler?
): ...any
	-- 在表格中捕获元组值
	-- 我们在此使用 retryAsync 重试失败的调用，并采用指数式延迟
	local attemptReturnValues = {
		retryAsync(function()
			local dataStore = self:getDataStore()

			return operation(dataStore)
		end, self._maxAttempts, self._retryConstant, self._retryExponent, optionalRetryFunctionHandler),
	}

	-- retryAsync 返回受保护的调用模式（成功、...）
	local attemptSuccess = table.remove(attemptReturnValues, 1) :: boolean

	-- ThreadQueue 使用 pcall 调用任务，因此在这里，我们不会返回 success、result 或 false。
	-- 模式，而是在成功为假时抛出
	if not attemptSuccess then
		-- 尝试失败，通过线程队列将错误上报
		local errorMessage = attemptReturnValues[1]
		error(errorMessage)
	end

	-- 尝试成功，返回结果元组中的所有值
	return table.unpack(attemptReturnValues)
end

function DataStoreWrapper.getAsync(
	self: ClassType,
	key: string,
	optionalRetryFunctionHandler: retryAsync.FunctionHandler?
): (boolean, any | string, DataStoreKeyInfo?)
	return self:_attemptAsync(key, function(dataStore: GlobalDataStore)
		return dataStore:GetAsync(key)
	end, optionalRetryFunctionHandler)
end

function DataStoreWrapper.setAsync(
	self: ClassType,
	key: string,
	value: any,
	userIds: { number }?,
	options: DataStoreSetOptions?,
	optionalRetryFunctionHandler: retryAsync.FunctionHandler?
): (boolean, string?)
	return self:_attemptAsync(key, function(dataStore: GlobalDataStore)
		--warn(key, value, userIds, options)
		return dataStore:SetAsync(key, value, userIds, options)
	end, optionalRetryFunctionHandler)
end

function DataStoreWrapper.removeAsync(
	self: ClassType,
	key: string,
	optionalRetryFunctionHandler: retryAsync.FunctionHandler?
): (boolean, any | string, DataStoreKeyInfo?)
	return self:_attemptAsync(key, function(dataStore: GlobalDataStore)
		return dataStore:RemoveAsync(key)
	end, optionalRetryFunctionHandler)
end


function DataStoreWrapper._requestAsync(
	self: ClassType,
	key: string,
	transformCallback: TransformCallback	
): (boolean, string | any, DataStoreKeyInfo?)

	local success, result: any, keyInfo = self:updateAsync(
		key,
		function(currentValue: any, currentKeyInfo: DataStoreKeyInfo?)

			if currentValue == NIL_STRING_PLACEHOLDER then
				currentValue = nil
			end


			local value, userIds, metadata = noYield(transformCallback, currentValue, currentKeyInfo)
	
			metadata = metadata or {}

			if value == nil then
				value = NIL_STRING_PLACEHOLDER
			end


			return value, userIds, metadata
		end
	)

	if success then

		if result == NIL_STRING_PLACEHOLDER then
			result = nil
		end

		--local metadata = if keyInfo then keyInfo:GetMetadata() else nil

	end

	return success, result, keyInfo
end


function DataStoreWrapper._setAsync(
	self: ClassType,
	key: string,
	value: any,
	userIds: { number }?,
	options: DataStoreSetOptions?
): (boolean, string?)
	return self:_requestAsync(key, function()
		local metadata = if options then options:GetMetadata() else nil

		return value, userIds, metadata
	end)
end


function DataStoreWrapper.updateAsync(
	self: ClassType,
	key: string,
	transformFunction: TransformCallback,
	optionalRetryFunctionHandler: retryAsync.FunctionHandler?
): (boolean, any | string, DataStoreKeyInfo?)
	return self:_attemptAsync(key, function(dataStore: GlobalDataStore)
		return dataStore:UpdateAsync(key, transformFunction)
	end, optionalRetryFunctionHandler)
end

function DataStoreWrapper.getDataStore(self: ClassType): GlobalDataStore
	-- 缓存 DataStore 实例，同一 name 每次 GetDataStore 开销可省略
	if not self._cachedStore then
		self._cachedStore = DataStoreService:GetDataStore(self._name, nil, dataStoreOptions)
	end
	return self._cachedStore :: GlobalDataStore
end

function DataStoreWrapper.getQueueLength(self: ClassType, key: string): number
	local length = 0
	local threadQueue = self._keyQueues[key]

	if threadQueue then
		length = threadQueue:getLength()
	end

	return length
end

function DataStoreWrapper.areAllQueuesEmpty(self: ClassType): boolean
	for _, threadQueue in pairs(self._keyQueues) do
		if threadQueue:getLength() > 0 then
			return false
		end
	end

	return true
end

-- 与游戏关闭（game:BindToClose）绑定的代码在超时前的运行时间是有限的。
-- skipAllQueuesToLastEnqueued 方法可用于跳过所有线程队列到最近的请求，这样时间就不会浪费在过时的请求上。
-- 最近的请求，这样时间就不会浪费在过时的请求上。注意，此方法将丢弃
-- 存储在线程队列中的已生成线程，这意味着 DataStoreWrapper 调用这些
-- 过时的请求将不会返回。因此，只有在以下情况下才可使用 skipAllQueuesToLastEnqueued
-- 游戏关闭时使用。
function DataStoreWrapper.skipAllQueuesToLastEnqueued(self: ClassType)
	for _, threadQueue in pairs(self._keyQueues) do
		threadQueue:skipToLastEnqueued()
	end
end

return DataStoreWrapper


