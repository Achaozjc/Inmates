--!strict

--[[
	下载并存储游戏中每个开发者产品价格的类
	当以后需要这些信息时，如果不适合进行屈服的网络请求时，可以直接查询。
--]]

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local iterateOverPagesAsync = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Common.IterateOverPagesAsync)
local retryAsync = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Common.RetryAsync)
local Signal = require(ReplicatedStorage.ReplicatedCode.Framework.Packages.Signal)
local StoreIdCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.StoreIdCategory)

local MAX_RETRIES = 3
local RETRY_CONSTANT = 5
local RETRY_EXPONENT = 5
local PRICES_ATTRIBUTE = "DevProductPricesV1"
local FALLBACK_MAX_CONCURRENCY = 10 -- GetProductInfoAsync 并发上限，避免触发限流

local DevProductPriceList = {}
DevProductPriceList._prices = {} :: { [number]: number }
DevProductPriceList._setupSucceeded = nil :: boolean?
DevProductPriceList.readyChanged = Signal.new()

local function countPrices(): number
	local count = 0
	for _ in DevProductPriceList._prices do
		count += 1
	end
	return count
end

local function warnMissingStoreProducts(tag: string)
	local missingList: { string } = {}
	local missingCount = 0
	local productCount = 0

	for productKey, productId in StoreIdCategory.Product do
		productCount += 1
		if DevProductPriceList._prices[productId] == nil then
			missingCount += 1
			table.insert(missingList, `{productKey}={productId}`)
		end
	end

	table.sort(missingList)
	if missingCount > 0 then
		warn(`[DevProductPriceList] {tag} StoreIdCategory.Product total=`, productCount, "missing=", missingCount)
		warn(`[DevProductPriceList] {tag} missing entries:\n` .. table.concat(missingList, "\n"))
	end
end

local function loadFromDeveloperProducts()
	local developerProducts = MarketplaceService:GetDeveloperProductsAsync() :: Pages
	local loadedCount = 0
	local maxPageNumber = 0

	DevProductPriceList._prices = {}

	for developerProductInfo, pageNumber in iterateOverPagesAsync(developerProducts) :: any do
		if type(pageNumber) == "number" and pageNumber > maxPageNumber then
			maxPageNumber = pageNumber
		end
		DevProductPriceList._prices[developerProductInfo.ProductId] = developerProductInfo.PriceInRobux
		loadedCount += 1
	end

	print(
		"[DevProductPriceList] loadedCount=",
		loadedCount,
		"uniqueCount=",
		countPrices(),
		"maxPageNumber=",
		maxPageNumber
	)
end

local function fillMissingByGetProductInfo()
	local missingIdsMap: { [number]: boolean } = {}
	local missingIds: { number } = {}

	for _productKey, productId in StoreIdCategory.Product do
		if DevProductPriceList._prices[productId] == nil and not missingIdsMap[productId] then
			missingIdsMap[productId] = true
			table.insert(missingIds, productId)
		end
	end

	if #missingIds <= 0 then
		return
	end

	print("[DevProductPriceList] Pagination gap detected, fetching", #missingIds, "missing products via GetProductInfo")

	-- 并发抓取：避免串行 N × GetProductInfoAsync 累计耗时，通过信号量限流防限速
	local startTime = os.clock()
	local remaining = #missingIds
	local done = Instance.new("BindableEvent")
	local inFlight = 0
	local nextIndex = 1

	local function launchOne()
		while inFlight < FALLBACK_MAX_CONCURRENCY and nextIndex <= #missingIds do
			local productId = missingIds[nextIndex]
			nextIndex += 1
			inFlight += 1
			task.spawn(function()
				local ok, productInfo = pcall(function()
					return MarketplaceService:GetProductInfoAsync(productId, Enum.InfoType.Product)
				end)
				if ok and productInfo and productInfo.PriceInRobux then
					DevProductPriceList._prices[productId] = productInfo.PriceInRobux
				else
					warn("[DevProductPriceList] Failed to fetch product info for productId=", productId, ok and productInfo or "nil")
				end
				inFlight -= 1
				remaining -= 1
				if remaining <= 0 then
					done:Fire()
				else
					launchOne()
				end
			end)
		end
	end

	launchOne()
	done.Event:Wait()
	done:Destroy()

	print(
		"[DevProductPriceList] After GetProductInfo fallback: total=",
		countPrices(),
		"elapsed=",
		string.format("%.2fs", os.clock() - startTime)
	)
end

local function publishPricesToReplicatedStorage()
	local encoded = HttpService:JSONEncode(DevProductPriceList._prices)
	ReplicatedStorage:SetAttribute(PRICES_ATTRIBUTE, encoded)
end

local function loadPricesFromReplicatedStorage(): boolean
	local encoded = ReplicatedStorage:GetAttribute(PRICES_ATTRIBUTE)
	if type(encoded) ~= "string" or encoded == "" then
		return false
	end

	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(encoded)
	end)
	if not ok or type(decoded) ~= "table" then
		return false
	end

	local parsed: { [number]: number } = {}
	for key, value in decoded do
		local productId = tonumber(key)
		if productId and type(value) == "number" then
			parsed[productId] = value
		end
	end

	DevProductPriceList._prices = parsed
	return true
end

function DevProductPriceList.setupAsync()
	local success, result = retryAsync(function()
		if game.PlaceId == 0 then
			-- Studio 未发布文件：Server 不会发布 Attribute，Client 镜像短路避免硬等超时
			return
		end

		if RunService:IsServer() then
			loadFromDeveloperProducts()
			fillMissingByGetProductInfo()
			publishPricesToReplicatedStorage()
			warnMissingStoreProducts("server")
			return
		end

		if loadPricesFromReplicatedStorage() then
			warnMissingStoreProducts("client")
			return
		end

		local changedSignal = ReplicatedStorage:GetAttributeChangedSignal(PRICES_ATTRIBUTE)
		local bindable = Instance.new("BindableEvent")
		local finished = false
		local timedOut = false

		local function tryFinish(loaded: boolean)
			if finished then
				return
			end
			finished = true
			bindable:Fire(loaded)
		end

		local connection: RBXScriptConnection? = changedSignal:Connect(function()
			if loadPricesFromReplicatedStorage() then
				tryFinish(true)
			end
		end)

		-- 关闭 Connect 前 Server 已写入的竞态窗口
		if loadPricesFromReplicatedStorage() then
			tryFinish(true)
		end

		task.delay(10, function()
			if finished then
				return
			end
			timedOut = true
			tryFinish(false)
		end)

		local loaded = bindable.Event:Wait()
		if connection then
			connection:Disconnect()
		end
		bindable:Destroy()

		if loaded then
			--print("[DevProductPriceList] Loaded prices from ReplicatedStorage sync, total=", countPrices())
			warnMissingStoreProducts("client")
			return
		end

		error(if timedOut then "Timed out waiting for server price sync" else "Failed to load prices from server sync")
	end, MAX_RETRIES, RETRY_CONSTANT, RETRY_EXPONENT)

	DevProductPriceList._setupSucceeded = success
	DevProductPriceList.readyChanged:Fire(success)

	if not success then
		warn("Failed to load developer product info: " .. tostring(result))
	end
end

function DevProductPriceList.get(developerProductId: number): number?
	return DevProductPriceList._prices[developerProductId]
end

function DevProductPriceList.isReady(): boolean
	return DevProductPriceList._setupSucceeded == true
end

return DevProductPriceList
