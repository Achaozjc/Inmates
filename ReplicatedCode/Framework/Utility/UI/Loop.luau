--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MemoryStoreService = game:GetService("MemoryStoreService")

local retryAsync = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Common.RetryAsync)
local SetSequentialInterval = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Time.SetSequentialInterval)


local TAKEOVER_INTERVAL_MULTIPLIER = 2
local LEADER_EXPIRATION_MULTIPLIER = 2
-- Key expiration is set to longer than leadership expiration so that delta times can be
-- kept consistent if the leader server crashes
-- 密钥过期时间设置为长于领导者过期时间，以便在领导者服务器崩溃时
-- 保持一致
local KEY_EXPIRATION_MULTIPLIER = 3
local KEY = "Info"

local UPDATE_ATTEMPTS = 3
local UPDATE_RETRY_PAUSE_CONSTANT = 2
local UPDATE_RETRY_PAUSE_EXPONENT_BASE = 2

local LoopMode = {
	Idle = "Idle",
	Update = "Update",
	Takeover = "Takeover",
}

type LeaderInfo = {
	Leader: string,
	LastUpdate: number,
	LeaderExpiration: number,
}

local Loop = {}
Loop.__index = Loop

function Loop.new(id: string, interval: number, updateFunction: (number) -> ())
	local self = {
		id = id,
		_started = false,
		_mode = LoopMode.Idle,
		_memoryStore = MemoryStoreService:GetSortedMap(string.format("Loop_%s", id)),
		_updateInterval = interval,
		_takeoverInterval = interval * TAKEOVER_INTERVAL_MULTIPLIER,
		_leaderExpiration = interval * LEADER_EXPIRATION_MULTIPLIER,
		_keyExpiration = interval * KEY_EXPIRATION_MULTIPLIER,
		_updateFunction = updateFunction,
		_clearIntervalFunction = nil,
	}

	setmetatable(self, Loop)

	return self
end

-- Set a function to be called on an interval, taking into account the time it takes for the function to complete if it is Async
-- Only one function can be set to be called at once
-- 设置函数的调用间隔，如果函数是同步的，则要考虑函数完成所需的时间
-- 一次只能调用一个函数
function Loop:_setIntervalFunction(functionToCall: () -> (), interval: number)
	if self._clearIntervalFunction then
		(self._clearIntervalFunction :: any)()
	end

	self._clearIntervalFunction = SetSequentialInterval(functionToCall, interval)
end

-- Attempt to take over leadership of the loop
function Loop:_attemptTakeoverAsync(): boolean
	local tookLeadership = false

	local success = pcall(function()
		self._memoryStore:UpdateAsync(KEY, function(oldInfo): LeaderInfo?
			-- When the same key is updated by multiple servers at once, this callback may be called multiple
			-- times in order to resolve correctly. Since we have a flag variable that was defined outside of
			-- this scope, we need to reset it at the start of each callback.
			-- 当多个服务器同时更新同一密钥时，该回调可能会被调用多
			-- 调用多次才能正确解析。由于我们的标志变量是在
			-- 我们需要在每次回调开始时重置它。
			tookLeadership = false
			local newInfo = oldInfo :: LeaderInfo?
			local now = DateTime.now().UnixTimestamp

			if newInfo then
				local isThisServerLeader = newInfo.Leader == game.JobId
				local isLeaderExpired = now > newInfo.LeaderExpiration

				if isThisServerLeader or isLeaderExpired then
					-- Leadership can expire in 3 cases:
					--   1. The server crashed and is no longer refreshing its expiration
					--   2. The server is getting MemoryStore API errors or being throttled
					--   3. The server shut down and released leadership, setting expiration to 0
					-- If the server fails to relinquish leadership for some reason, it can enter into the
					-- takeover loop while still retaining leadership in MemoryStore. In this case the
					-- server will attempt to take over leadership again.
					-- 在三种情况下，"领导力 "可能会过期：
					-- 服务器崩溃，不再刷新过期时间
					-- 2. 服务器出现内存存储 API 错误或被节流
					-- 3. 服务器关闭并释放了领导权，将过期时间设置为 0
					-- 如果服务器由于某种原因未能放弃领导权，它可能会进入
					-- 接管循环，同时仍保留 MemoryStore 的领导权。在这种情况下
					-- 服务器将再次尝试接管领导权。
					newInfo.Leader = game.JobId
					newInfo.LeaderExpiration = now + self._leaderExpiration

					tookLeadership = true
				end
			else
				newInfo = {
					Leader = game.JobId,
					LastUpdate = now,
					LeaderExpiration = now + self._leaderExpiration,
				} :: LeaderInfo

				tookLeadership = true
			end

			return if tookLeadership then newInfo else nil
		end, self._keyExpiration)
	end)

	return success and tookLeadership
end

-- Attempt to run the Update function for the loop-- 尝试运行循环的更新函数
function Loop:_attemptUpdateAsync()
	local memoryStoreSuccess, lastUpdate = retryAsync(function()
		local oldUpdate: number? = nil

		self._memoryStore:UpdateAsync(KEY, function(oldInfo): LeaderInfo?
			oldUpdate = nil
			local newInfo = oldInfo :: LeaderInfo?
			local now = DateTime.now().UnixTimestamp

			if newInfo and newInfo.Leader == game.JobId then
				oldUpdate = newInfo.LastUpdate
				newInfo.LastUpdate = now
				newInfo.LeaderExpiration = now + self._leaderExpiration

				return newInfo
			else
				return nil
			end
		end, self._keyExpiration)

		return oldUpdate
	end, UPDATE_ATTEMPTS, UPDATE_RETRY_PAUSE_CONSTANT, UPDATE_RETRY_PAUSE_EXPONENT_BASE)

	if memoryStoreSuccess and lastUpdate then
		local updateSuccess = retryAsync(function()
			local now = DateTime.now().UnixTimestamp
			self._updateFunction(now - lastUpdate)
		end, UPDATE_ATTEMPTS, UPDATE_RETRY_PAUSE_CONSTANT, UPDATE_RETRY_PAUSE_EXPONENT_BASE)
		return updateSuccess
	end

	return false
end

-- Release leadership of the loop, allowing another server to take control-- 释放循环的领导权，让其他服务器接管控制权
function Loop:_releaseLeadershipAsync()
	retryAsync(function()
		self._memoryStore:UpdateAsync(KEY, function(oldInfo): LeaderInfo?
			local newInfo = oldInfo :: LeaderInfo?

			if newInfo and newInfo.Leader == game.JobId then
				newInfo.LeaderExpiration = 0
				return newInfo
			else
				return nil
			end
		end, self._keyExpiration)
	end, UPDATE_ATTEMPTS, UPDATE_RETRY_PAUSE_CONSTANT, UPDATE_RETRY_PAUSE_EXPONENT_BASE)
end

function Loop:_startTakeoverLoop()
	assert(self._mode ~= LoopMode.Takeover, string.format("Loop '%s' is already in takeover mode!", self.id))

	self._mode = LoopMode.Takeover
	self:_setIntervalFunction(function()
		local success = self:_attemptTakeoverAsync()
		if success then
			self:_startUpdateLoop()
		end
	end, self._takeoverInterval)
end

function Loop:_startUpdateLoop()
	assert(self._mode ~= LoopMode.Update, string.format("Loop '%s' is already in update mode!", self.id))

	self._mode = LoopMode.Update
	self:_setIntervalFunction(function()
		local success = self:_attemptUpdateAsync()
		if not success then
			self:_startTakeoverLoop()
		end
	end, self._updateInterval)
end

function Loop:start()
	assert(not self._started, "Loop is already started!")
	self._started = true

	game:BindToClose(function()
		-- 结束当前的时间间隔循环，这样我们就不会在关机时试图获取领导权
		-- End the current interval loop so we don't try to take leadership while shutting down
		if self._clearIntervalFunction then
			(self._clearIntervalFunction :: any)()
		end
		-- 如果循环当前处于更新模式（即该服务器已经是领导者），则释放领导权
		-- If the loop is currently in Update mode (i.e. this server is already the leader), release leadership
		if self._mode == LoopMode.Update then
			self:_releaseLeadershipAsync()
		end
	end)
	-- 以接管模式启动
	-- Start in Takeover mode
	self:_startTakeoverLoop()
end

return Loop


