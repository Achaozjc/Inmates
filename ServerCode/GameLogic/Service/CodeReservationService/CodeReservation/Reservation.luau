--!strict

local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(script.Parent.Constants)
local retryAsync = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Common.RetryAsync)
local SetSequentialInterval = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Time.SetSequentialInterval)
local getItemsFitting = require(script.Parent.getItemsFitting)

local LOW_STOCK_WARN_INTERVAL = 300

local Reservation = {}
Reservation.__index = Reservation

function Reservation.new(key: string, reserveCount: number)
	local memoryStore = MemoryStoreService:GetSortedMap(string.format(Constants.MEMORY_STORE_NAME_TEMPLATE, key))
	local self = {
		_open = false,
		_key = key,
		_codes = {},
		_usedCodesToRegister = {},
		_reserveCount = reserveCount,
		_clearUpdate = nil :: (() -> nil)?,
		_memoryStore = memoryStore,
		_lastLowStockWarnAt = -LOW_STOCK_WARN_INTERVAL,
	}
	setmetatable(self, Reservation)
	return self
end

function Reservation:_reserveCodesAsync(numCodesToReserve: number)
	local success, result = retryAsync(function()
		local codes: { string } = {}

		self._memoryStore:UpdateAsync(Constants.MEMORY_STORE_AVAILABLE_KEY, function(oldData)
			codes = {}
			if not oldData then
				oldData = {}
			end
			local newData = oldData :: { string }

			while #codes < numCodesToReserve and #newData > 0 do
				local code = table.remove(newData, 1) :: string
				table.insert(codes, code)
			end

			return newData
		end, Constants.MEMORY_STORE_EXPIRATION)

		return codes
	end, Constants.UPDATE_ATTEMPTS, Constants.UPDATE_RETRY_PAUSE_CONSTANT, Constants.UPDATE_RETRY_PAUSE_EXPONENT_BASE)

	if success then
		local reservedCodes = result :: { string }
		if #reservedCodes < numCodesToReserve then
			local now = os.clock()
			if now - self._lastLowStockWarnAt >= LOW_STOCK_WARN_INTERVAL then
				self._lastLowStockWarnAt = now
				warn(string.format(
					"Reservation '%s' low on codes. Retrieved: %d/%d",
					self._key,
					#reservedCodes,
					numCodesToReserve
				))
			end
		end

		for _, code in reservedCodes do
			table.insert(self._codes, code)
		end

		return true
	else
		return false, "Failed to reserve codes because: " .. tostring(result)
	end
end

function Reservation:_transferCodesToMemoryAsync(key: string, codes: { string }): (boolean, string?)
	if #codes == 0 then
		return true
	end

	local memoryStore = self._memoryStore :: MemoryStoreSortedMap
	local codesToAdd: { string } = {}

	local success, result = retryAsync(function()
		memoryStore:UpdateAsync(key, function(oldData): { string }?
			codesToAdd = table.clone(codes)
			if #codesToAdd == 0 then
				return nil
			end
			if not oldData then
				oldData = {}
			end
			local newData = oldData :: { string }

			codesToAdd = getItemsFitting(newData, codesToAdd, Constants.MEMORY_STORE_VALUE_MAX_SIZE)
			if #codesToAdd == 0 then
				return nil
			end

			for _, code in codesToAdd do
				if table.find(newData, code) then
					warn("Something bad happened! Attempted to insert duplicate " .. key .. " code")
				else
					table.insert(newData, code)
				end
			end

			return newData
		end, Constants.MEMORY_STORE_EXPIRATION)
	end, Constants.UPDATE_ATTEMPTS, Constants.UPDATE_RETRY_PAUSE_CONSTANT, Constants.UPDATE_RETRY_PAUSE_EXPONENT_BASE)

	if success then
		for _, code in codesToAdd do
			local index = table.find(codes, code)
			if index then
				table.remove(codes, index)
			end
		end

		return true
	else
		return false, "Failed to add " .. key .. " codes to MemoryStore because: " .. tostring(result)
	end
end

function Reservation:_updateAsync()
	if not self._open then
		return
	end

	local reserveCount = self._reserveCount :: number
	local numCodesToFill = reserveCount - #self._codes
	local minimumCodesForUpdate = math.floor(reserveCount * Constants.MINIMUM_CODES_PERCENT_TO_UPDATE)
	local requiresNewCodes = #self._codes <= minimumCodesForUpdate
	local hasUsedCodesToRegister = #self._usedCodesToRegister > 0

	if not (requiresNewCodes or hasUsedCodesToRegister) then
		return
	end

	if requiresNewCodes then
		local success, result = self:_reserveCodesAsync(numCodesToFill)
		if not success then
			warn(result)
		end
	end

	if hasUsedCodesToRegister then
		local success, result =
			self:_transferCodesToMemoryAsync(Constants.MEMORY_STORE_USED_KEY, self._usedCodesToRegister)
		if not success then
			warn(result)
		end
	end
end

function Reservation:hasCodes(): boolean
	return #self._codes > 0
end

function Reservation:getCode(): string
	assert(self:hasCodes(), "No codes available!")
	local code = table.remove(self._codes, 1) :: string
	table.insert(self._usedCodesToRegister, code)
	return code
end

function Reservation:open()
	assert(not self._open, "Reservation '" .. self._key :: string .. "' is already open")

	self._open = true
	task.spawn(function()
		self:_updateAsync()
		self._clearUpdate = SetSequentialInterval(function()
			self:_updateAsync()
		end, Constants.RESERVATION_UPDATE_INTERVAL)
	end)
end

function Reservation:closeAsync()
	if self._clearUpdate then
		self._clearUpdate()
	end

	local releaseSuccess, releaseResult =
		self:_transferCodesToMemoryAsync(Constants.MEMORY_STORE_RELEASED_KEY, self._codes)
	if not releaseSuccess then
		warn(releaseResult)
	end

	local registerUsedSuccess, registerUsedResult =
		self:_transferCodesToMemoryAsync(Constants.MEMORY_STORE_USED_KEY, self._usedCodesToRegister)
	if not registerUsedSuccess then
		warn(registerUsedResult)
	end

	self._open = false
end

return Reservation
