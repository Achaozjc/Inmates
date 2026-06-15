--!strict
-- 预生成码池 Service：start 时 openReservation 配置的 key；发码记入 IssuedReservationCodes，兑换时由 RewardService 查本表+ReservationCodeRewards 发奖

local DataStoreService = game:GetService("DataStoreService")
local CodeReservation = require(script.CodeReservation)
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReservationCodeRewards = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Configs.ReservationCodeRewards)

type IssuedCodeRecord = {
	key: string,
	issuedAt: number,
	expireAt: number,
	redeemed: boolean,
}

-- 本服缓存：codeString -> record（权威数据在 DataStore，用于跨服与重启恢复）
local IssuedReservationCodes: { [string]: IssuedCodeRecord } = {}
local ISSUED_CODES_DATASTORE_NAME = "ReservationIssuedCodes_v1"
local ISSUED_CODES_DATASTORE_KEY_PREFIX = "code:"
local DEFAULT_EXPIRE_DAYS = 7

-- 需要在 start 时打开的 reservation key 及预留数量（可按需扩展为配置表）
local DEFAULT_RESERVATION_KEYS: { { key: string, reserveCount: number? } } = {
	-- { key = "Event2025", reserveCount = 20 },
}

local CodeReservationService = {}
local _issuedCodesStore = DataStoreService:GetDataStore(ISSUED_CODES_DATASTORE_NAME)
local _statsCache: { [string]: { issued: number, redeemed: number } } = {}

local function _statsKey(poolKey: string): string
	return "stats:" .. poolKey
end

local function _updateStats(poolKey: string, deltaIssued: number, deltaRedeemed: number)
	if not _statsCache[poolKey] then
		local ok, result = pcall(function()
			return _issuedCodesStore:GetAsync(_statsKey(poolKey))
		end)
		if ok and type(result) == "table" then
			_statsCache[poolKey] = {
				issued = math.max(0, tonumber(result.issued) or 0),
				redeemed = math.max(0, tonumber(result.redeemed) or 0),
			}
		else
			_statsCache[poolKey] = { issued = 0, redeemed = 0 }
		end
	end
	
	_statsCache[poolKey].issued = math.max(0, _statsCache[poolKey].issued + deltaIssued)
	_statsCache[poolKey].redeemed = math.max(0, _statsCache[poolKey].redeemed + deltaRedeemed)

	task.spawn(function()
		pcall(function()
			_issuedCodesStore:UpdateAsync(_statsKey(poolKey), function(old)
				if type(old) ~= "table" then
					old = { issued = 0, redeemed = 0 }
				end
				return {
					issued = math.max(0, (old.issued or 0) + deltaIssued),
					redeemed = math.max(0, (old.redeemed or 0) + deltaRedeemed),
				}
			end)
		end)
	end)
end

-- 预留码严格区分大小写：DataStore key、缓存、比对均以原始 code 为准，
-- 避免同一个码以不同大小写被领取多次
local function _getIssuedCodeDataKey(code: string): string
	return ISSUED_CODES_DATASTORE_KEY_PREFIX .. code
end

local function _getExpireDaysForKey(key: string): number
	local poolConfig = ReservationCodeRewards.Rewards[key]
	local expireDays = poolConfig and tonumber(poolConfig.expireDays)
	if typeof(expireDays) == "number" and expireDays > 0 then
		return math.floor(expireDays)
	end
	return DEFAULT_EXPIRE_DAYS
end

local function _saveIssuedCodeRecord(code: string, record: IssuedCodeRecord)
	local ok, err = pcall(function()
		_issuedCodesStore:SetAsync(_getIssuedCodeDataKey(code), record)
	end)
	if not ok then
		warn("Reservation code record save failed: " .. tostring(err))
	end
end

local function _loadIssuedCodeRecord(code: string): IssuedCodeRecord?
	local cached = IssuedReservationCodes[code]
	if cached then
		return cached
	end

	local ok, result = pcall(function()
		return _issuedCodesStore:GetAsync(_getIssuedCodeDataKey(code))
	end)
	if not ok or type(result) ~= "table" then
		return nil
	end

	local loaded = result :: IssuedCodeRecord
	IssuedReservationCodes[code] = loaded
	return loaded
end

function CodeReservationService.start()
	for _, item in DEFAULT_RESERVATION_KEYS do
		CodeReservation.openReservation(item.key, item.reserveCount)
	end
end

function CodeReservationService.listen()
	-- 无额外监听
end

-- 对外：是否还有可发码
function CodeReservationService.reservationHasCodes(key: string): boolean
	return CodeReservation.reservationHasCodes(key)
end

-- 对外：从池中取一个码（仅服务端发码时调用）
function CodeReservationService.getCode(key: string): (boolean, string?)
	return CodeReservation.getCode(key)
end

-- 给玩家发一张预生成码：取码、记表、返回码字符串和过期时间（由调用方通过 NetSignals 等发给玩家）
function CodeReservationService.givePlayerReservationCode(player: Player, key: string): (boolean, string?, number?)
	if not CodeReservation.isReservationOpen(key) then
		local stock = CodeReservation.getPoolStockAsync(key)
		if stock.available + stock.reserved <= 0 then
			return false, nil
		end
		CodeReservation.openReservation(key, 20) -- 默认动态预留 20 个
	end

	local success, codeString = CodeReservation.getCode(key)
	if not success or not codeString then
		-- 首次取码失败时：码可能在 MemoryStore（Reserved）或 DataStore（Available）中
		-- 等待 Manager 完成加载窗口后重试；只有池里完全无码才放弃
		local stock = CodeReservation.getPoolStockAsync(key)
		if stock.available + stock.reserved > 0 then
			for _ = 1, 40 do
				task.wait(0.25)
				success, codeString = CodeReservation.getCode(key)
				if success and codeString then
					break
				end
			end
		end
	end

	if not success or not codeString then
		return false, nil
	end

	local now = workspace:GetServerTimeNow()
	local expireDays = _getExpireDaysForKey(key)
	local record: IssuedCodeRecord = {
		key = key,
		issuedAt = now,
		expireAt = now + expireDays * 24 * 60 * 60,
		redeemed = false,
	}
	
	IssuedReservationCodes[codeString] = record
	_saveIssuedCodeRecord(codeString, record)
	_updateStats(key, 1, 0)
	
	-- 返回过期时间和码
	return true, codeString, record.expireAt
end

-- 查已发码并校验状态（支持跨服/重启）
function CodeReservationService.getKeyForIssuedCode(code: string): (string?, string?)
	local record = _loadIssuedCodeRecord(code)
	if not record then
		return nil, "Code unavailable"
	end

	if record.redeemed then
		return nil, "Code used"
	end

	if workspace:GetServerTimeNow() > (tonumber(record.expireAt) or 0) then
		return nil, "Code expired!"
	end

	return record.key, nil
end

-- 兑换成功后移除记录，防止重复领取
function CodeReservationService.markIssuedCodeRedeemed(code: string)
	local record = _loadIssuedCodeRecord(code)
	if not record then
		return
	end

	record.redeemed = true
	IssuedReservationCodes[code] = record
	_saveIssuedCodeRecord(code, record)
	-- 兑换时仅增加已兑换计数，不扣除已发放计数，使得“已发”代表总发放量
	_updateStats(record.key, 0, 1)

	-- 强制将池中的码标记为 Used，确保存档里是 U (Used)
	CodeReservation.tryConsumeCodeAsync(record.key, code)
end

-- 尝试消费预生成码（核实有效性并标记状态）
function CodeReservationService.tryConsumeCodeAsync(key: string, code: string): boolean
	return CodeReservation.tryConsumeCodeAsync(key, code)
end

-- Studio 注册码池用
function CodeReservationService.registerCodesAsync(key: string, codes: { string })
	CodeReservation.registerCodesAsync(key, codes)
end

function CodeReservationService.registerRandomCodesAsync(key: string, count: number, prefix: string?): { string }
	return CodeReservation.registerRandomCodesAsync(key, count, prefix)
end

function CodeReservationService.getPoolStockAsync(key: string): { available: number, reserved: number, used: number, total: number }
	return CodeReservation.getPoolStockAsync(key)
end

-- 从 DataStore 读取持久化的已发/已兑计数（跨服、跨重启准确）
function CodeReservationService.getIssuedStatsForKey(key: string): { issued: number, redeemed: number }
	if _statsCache[key] then
		return {
			issued = _statsCache[key].issued,
			redeemed = _statsCache[key].redeemed,
		}
	end

	local ok, result = pcall(function()
		return _issuedCodesStore:GetAsync(_statsKey(key))
	end)
	if ok and type(result) == "table" then
		local stats = {
			issued = math.max(0, tonumber(result.issued) or 0),
			redeemed = math.max(0, tonumber(result.redeemed) or 0),
		}
		_statsCache[key] = stats
		return stats
	end
	return { issued = 0, redeemed = 0 }
end

function CodeReservationService.clearPoolAsync(key: string)
	_statsCache[key] = { issued = 0, redeemed = 0 }
	
	CodeReservation.clearPoolAsync(key)
	task.spawn(function()
		pcall(function()
			_issuedCodesStore:SetAsync(_statsKey(key), { issued = 0, redeemed = 0 })
		end)
	end)
end

return CodeReservationService
