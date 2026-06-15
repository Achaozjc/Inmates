--!strict

local DataStoreService = game:GetService("DataStoreService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CodeStatus = require(script.Parent.CodeStatus)
local Constants = require(script.Parent.Constants)
local LeaderElection = require(script.Parent.LeaderElection)
local getItemsFitting = require(script.Parent.getItemsFitting)
local retryAsync = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Common.RetryAsync)

type CodeStatusMap = { [string]: string }

local Manager = {}
Manager.__index = Manager

function Manager.new(key: string)
	local dataStore = DataStoreService:GetDataStore(string.format(Constants.DATA_STORE_NAME_TEMPLATE, key))
	local memoryStore = MemoryStoreService:GetSortedMap(string.format(Constants.MEMORY_STORE_NAME_TEMPLATE, key))

	local self = {
		_dataStore = dataStore,
		_memoryStore = memoryStore,
		_key = key,
	}
	setmetatable(self, Manager)
	return self
end

function Manager:_getCodesFromMemoryAsync(key: string): { string }
	local memoryStore = self._memoryStore :: MemoryStoreSortedMap

	local success, result = pcall(function()
		return memoryStore:GetAsync(key)
	end)

	if success then
		if type(result) == "table" then
			return result :: { string }
		end
		return {}
	else
		warn("Failed to get " .. key .. " codes from MemoryStore because: " .. tostring(result))
		return {}
	end
end

function Manager:_removeCodesFromMemoryAsync(key: string, codes: { string })
	local memoryStore = self._memoryStore :: MemoryStoreSortedMap

	local success, result = retryAsync(function()
		memoryStore:UpdateAsync(key, function(oldData): { string }?
			if not oldData then
				warn("Attempted to remove codes from " .. key .. ", but no data exists")
				return nil
			end
			local newData = oldData :: { string }

			for _, code in codes do
				local index = table.find(newData, code)
				if index then
					table.remove(newData, index)
				end
			end

			return newData
		end, Constants.MEMORY_STORE_EXPIRATION)
	end, Constants.UPDATE_ATTEMPTS, Constants.UPDATE_RETRY_PAUSE_CONSTANT, Constants.UPDATE_RETRY_PAUSE_EXPONENT_BASE)

	if not success then
		warn("Failed to remove " .. key .. " codes from MemoryStore because: " .. tostring(result))
	end
end

function Manager:_saveUsedAndReleasedCodesAsync(): (boolean, string?)
	local dataStore = self._dataStore :: GlobalDataStore

	local usedCodes: { string } = self:_getCodesFromMemoryAsync(Constants.MEMORY_STORE_USED_KEY)
	local releasedCodes: { string } = self:_getCodesFromMemoryAsync(Constants.MEMORY_STORE_RELEASED_KEY)

	if #usedCodes == 0 and #releasedCodes == 0 then
		return true
	end

	local updateDataSuccess, updateDataResult = retryAsync(function()
		dataStore:UpdateAsync(Constants.DATA_STORE_CODES_KEY, function(oldData): CodeStatusMap?
			if not oldData then
				warn("DataStore for " .. self._key :: string .. " has not been initialized!")
				return nil
			end
			local newData = table.clone(oldData :: CodeStatusMap)

			for _, code in usedCodes do
				if newData[code] == CodeStatus.Used then
					warn("Attempted to mark a code as Used twice: " .. code)
				else
					newData[code] = CodeStatus.Used
				end
			end

			for _, code in releasedCodes do
				if newData[code] == CodeStatus.Used then
					warn("Attempted to release a Used code: " .. code)
				else
					newData[code] = CodeStatus.Available
				end
			end

			return newData
		end)
	end, Constants.UPDATE_ATTEMPTS, Constants.UPDATE_RETRY_PAUSE_CONSTANT, Constants.UPDATE_RETRY_PAUSE_EXPONENT_BASE)

	if not updateDataSuccess then
		return false, "Failed to update codes in DataStore because: " .. tostring(updateDataResult)
	end

	self:_removeCodesFromMemoryAsync(Constants.MEMORY_STORE_USED_KEY, usedCodes)
	self:_removeCodesFromMemoryAsync(Constants.MEMORY_STORE_RELEASED_KEY, releasedCodes)

	return true
end

function Manager:_makeCodesAvailableAsync(): (boolean, string?)
	local memoryStore = self._memoryStore :: MemoryStoreSortedMap
	local dataStore = self._dataStore :: GlobalDataStore

	local newAvailableCodes: { string } = {}

	local updateDataSuccess, updateDataResult = retryAsync(function()
		local availableCodesInMemory: { string } = self:_getCodesFromMemoryAsync(Constants.MEMORY_STORE_AVAILABLE_KEY)
		-- MemoryStore 为空时，DataStore 中状态仍为 Reserved 的码视为孤儿码（上次服务器未正常关服），
		-- 重置为 Available 以便本轮重新入队。
		local memoryIsEmpty = #availableCodesInMemory == 0

		dataStore:UpdateAsync(Constants.DATA_STORE_CODES_KEY, function(oldData): CodeStatusMap?
			newAvailableCodes = {}
			if not oldData then
				warn("DataStore for " .. self._key :: string .. " has not been initialized!")
				return nil
			end
			local newData = table.clone(oldData :: CodeStatusMap)

			local availableCodes = {}
			for code, status in newData do
				if status == CodeStatus.Available then
					table.insert(availableCodes, code)
				elseif status == CodeStatus.Reserved and memoryIsEmpty then
					newData[code] = CodeStatus.Available
					table.insert(availableCodes, code)
				end
			end

			newAvailableCodes =
				getItemsFitting(availableCodesInMemory, availableCodes, Constants.MEMORY_STORE_VALUE_MAX_SIZE)

			if #newAvailableCodes == 0 then
				return nil
			end

			for _, code in newAvailableCodes do
				newData[code] = CodeStatus.Reserved
			end

			return newData
		end)
	end, Constants.UPDATE_ATTEMPTS, Constants.UPDATE_RETRY_PAUSE_CONSTANT, Constants.UPDATE_RETRY_PAUSE_EXPONENT_BASE)

	if not updateDataSuccess then
		return false, "Failed to reserve codes from DataStore because: " .. tostring(updateDataResult)
	end

	if #newAvailableCodes == 0 then
		return true
	end

	local updateAvailableSuccess, updateAvailableResult = retryAsync(function()
		memoryStore:UpdateAsync(Constants.MEMORY_STORE_AVAILABLE_KEY, function(oldData): { string }?
			if not oldData then
				oldData = {}
			end
			local newData = oldData :: { string }

			for _, code in ipairs(newAvailableCodes) do
				table.insert(newData, code)
			end

			return newData
		end, Constants.MEMORY_STORE_EXPIRATION)
	end, Constants.UPDATE_ATTEMPTS, Constants.UPDATE_RETRY_PAUSE_CONSTANT, Constants.UPDATE_RETRY_PAUSE_EXPONENT_BASE)

	if not updateAvailableSuccess then
		return false, "Failed to add new Available codes to MemoryStore because: " .. tostring(updateAvailableResult)
	end

	return true
end

function Manager:_onLeaderUpdate()
	local saveSuccess, saveResult = self:_saveUsedAndReleasedCodesAsync()
	if not saveSuccess then
		warn(saveResult)
	end

	local makeAvailableSuccess, makeAvailableResult = self:_makeCodesAvailableAsync()
	if not makeAvailableSuccess then
		warn(makeAvailableResult)
	end
end

function Manager:initialize()
	-- 启动时先主动同步一次，避免首轮领导循环前码池为空
	task.spawn(function()
		self:_onLeaderUpdate()
	end)

	LeaderElection.startLoop(self._key, Constants.LEADER_UPDATE_INTERVAL, function()
		self:_onLeaderUpdate()
	end)
end

return Manager
