--!strict


local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")

local CodeStatus = require(script.CodeStatus)
local Constants = require(script.Constants)
local Manager = require(script.Manager)
local Reservation = require(script.Reservation)

local CodeReservationService = {
	_initialized = false,
	_reservations = {} :: { [string]: any },
	_managers = {} :: { [string]: any },
}

function CodeReservationService.tryConsumeCodeAsync(key: string, code: string): boolean
	local dataStore = DataStoreService:GetDataStore(string.format(Constants.DATA_STORE_NAME_TEMPLATE, key))

	-- 使用 UpdateAsync 来核实并消费码
	-- 我们不能简单地依赖结果，因为如果 code 本来就不存在，UpdateAsync 可能会被取消，这也被认为是 success=true
	local wasConsumed = false

	local success, result = pcall(function()
		return dataStore:UpdateAsync(Constants.DATA_STORE_CODES_KEY, function(oldData)
			if not oldData then
				return nil
			end
			local newData = table.clone(oldData :: { [string]: string })

			-- 严格区分大小写：只接受与池中登记完全一致的 code
			local currentStatus = newData[code]
			if currentStatus == CodeStatus.Available or currentStatus == CodeStatus.Reserved then
				newData[code] = CodeStatus.Used
				wasConsumed = true
				return newData
			end

			-- Code doesn't exist or is already used
			return nil
		end)
	end)

	return success and wasConsumed
end

function CodeReservationService.isReservationOpen(key: string): boolean
	return CodeReservationService._reservations[key] ~= nil
end

function CodeReservationService.registerCodesAsync(key: string, codes: { string })
	local dataStore = DataStoreService:GetDataStore(string.format(Constants.DATA_STORE_NAME_TEMPLATE, key))

	dataStore:UpdateAsync(Constants.DATA_STORE_CODES_KEY, function(oldData)
		if not oldData then
			oldData = {}
		end
		local newData = oldData :: { [string]: string }

		for _, code in codes do
			newData[code] = CodeStatus.Available
		end

		return newData
	end)
end

function CodeReservationService.registerRandomCodesAsync(key: string, count: number, prefix: string?): { string }
	local safeCount = math.max(1, math.floor(count))
	local codePrefix = (prefix and prefix ~= "") and prefix or key
	local generatedCodes = {}

	for _ = 1, safeCount do
		local token = string.gsub(HttpService:GenerateGUID(false), "-", ""):sub(1, 10)
		table.insert(generatedCodes, string.format("%s-%s", codePrefix, token))
	end

	CodeReservationService.registerCodesAsync(key, generatedCodes)
	return generatedCodes
end

function CodeReservationService.getPoolStockAsync(key: string): { available: number, reserved: number, used: number, total: number }
	local dataStore = DataStoreService:GetDataStore(string.format(Constants.DATA_STORE_NAME_TEMPLATE, key))
	local success, codesMap = pcall(function()
		return dataStore:GetAsync(Constants.DATA_STORE_CODES_KEY)
	end)

	if not success or type(codesMap) ~= "table" then
		return {
			available = 0,
			reserved = 0,
			used = 0,
			total = 0,
		}
	end

	local available = 0
	local reserved = 0
	local used = 0
	for _, status in pairs(codesMap :: { [string]: string }) do
		if status == CodeStatus.Available then
			available += 1
		elseif status == CodeStatus.Reserved then
			reserved += 1
		elseif status == CodeStatus.Used then
			used += 1
		end
	end

	return {
		available = available,
		reserved = reserved,
		used = used,
		total = available + reserved + used,
	}
end

function CodeReservationService.clearPoolAsync(key: string)
	local dataStore = DataStoreService:GetDataStore(string.format(Constants.DATA_STORE_NAME_TEMPLATE, key))
	local memoryStore = MemoryStoreService:GetSortedMap(string.format(Constants.MEMORY_STORE_NAME_TEMPLATE, key))

	dataStore:SetAsync(Constants.DATA_STORE_CODES_KEY, {})
	memoryStore:SetAsync(Constants.MEMORY_STORE_AVAILABLE_KEY, {}, Constants.MEMORY_STORE_EXPIRATION)
	memoryStore:SetAsync(Constants.MEMORY_STORE_USED_KEY, {}, Constants.MEMORY_STORE_EXPIRATION)
	memoryStore:SetAsync(Constants.MEMORY_STORE_RELEASED_KEY, {}, Constants.MEMORY_STORE_EXPIRATION)
end

function CodeReservationService.reservationHasCodes(key: string): boolean
	local reservation = CodeReservationService._reservations[key]
	assert(reservation, "Reservation '" .. key .. "' is not open")

	return reservation:hasCodes()
end

function CodeReservationService.getCode(key: string): (boolean, string?)
	local reservation = CodeReservationService._reservations[key]
	assert(reservation, "Reservation '" .. key .. "' is not open")

	if reservation:hasCodes() then
		local code = reservation:getCode()
		return true, code
	end

	for _ = 1, 10 do
		task.wait(0.2)
		if reservation:hasCodes() then
			local code = reservation:getCode()
			return true, code
		end
	end

	return false
end

function CodeReservationService.openReservation(key: string, reserveCount: number?)
	assert(not CodeReservationService._reservations[key], "Reservation '" .. key .. "' is already open")

	local reservation = Reservation.new(key, reserveCount or Players.MaxPlayers)

	if not CodeReservationService._managers[key] then
		local manager = Manager.new(key)
		CodeReservationService._managers[key] = manager
		manager:initialize()
	end

	CodeReservationService._reservations[key] = reservation
	reservation:open()
end

function CodeReservationService.closeReservationAsync(key: string)
	local reservation = CodeReservationService._reservations[key]
	assert(reservation, "Reservation '" .. key .. "' is not open")

	CodeReservationService._reservations[key] = nil
	reservation:closeAsync()
end

function CodeReservationService.closeAllReservationsAsync()
	for key in CodeReservationService._reservations do
		CodeReservationService.closeReservationAsync(key)
	end
end

function CodeReservationService._initialize()
	assert(not CodeReservationService._initialized, "CodeReservationService is already initialized")

	game:BindToClose(CodeReservationService.closeAllReservationsAsync)

	CodeReservationService._initialized = true
end

CodeReservationService._initialize()

return CodeReservationService
