local HttpService = game:GetService("HttpService")
local ServerScriptService = game:GetService("ServerScriptService")

local BaseUrl = "http://101.32.211.34:3000"
-- 只给 /api/place-metrics 用，与服务器 .env 里 PLACE_METRICS_KEY 一致（不要和 ApiKey 混用）
local PlaceMetricsKey = "4ed783780a7def1a5deed59aafed0c539a103f8c76c5be06ac1ffacf4d8a6949"

local OwnerId = 4595632038
local placeId = game.PlaceId

function printTable(t, indent)
	indent = indent or 0
	local indentStr = string.rep("  ", indent)
	for k, v in pairs(t) do
		if typeof(v) == "table" then
			print(indentStr .. tostring(k) .. ":")
			printTable(v, indent + 1)
		else
			print(indentStr .. tostring(k) .. ": " .. tostring(v))
		end
	end
end

local HttpProxyService = {}

local function get_http(url: string, headers: { any })
	local success, response = pcall(function()
		return HttpService:RequestAsync({
			Url = url,
			Method = "GET",
			Headers = headers,
		})
	end)
	if success and response.Success then
		local result = HttpService:JSONDecode(response.Body)
		return result
	else
		print("The request failed:", response.StatusCode, response.StatusMessage)
	end
	return nil
end

local function post_http(url: string, jsonData: { any }, headers: { any })
	local success, response = pcall(function()
		return HttpService:RequestAsync({
			Url = url,
			Method = "POST",
			Headers = headers,
			Body = HttpService:JSONEncode(jsonData),
		})
	end)

	if response.Success then
		print("Status code:", response.StatusCode, response.StatusMessage)
		print("Response body:\n", response.Body)
	else
		print("The request failed:", response.StatusCode, response.StatusMessage)
	end
end

function HttpProxyService.getPlayerIsFollowing(playerId: number, _cursor: any?)
	local url = BaseUrl .. "/api/player-follows"
	local body = HttpService:JSONEncode({
		playerId = playerId,
		targetUserId = OwnerId,
	})
	local ok, res = pcall(function()
		return HttpService:RequestAsync({
			Url = url,
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json",
				["x-place-metrics-key"] = PlaceMetricsKey,
			},
			Body = body,
		})
	end)
	if not ok or not res or not res.Success or not res.Body then
		return false
	end
	local data = HttpService:JSONDecode(res.Body)
	return typeof(data) == "table" and data.follows == true
end

local function getGameVoteFromTracker(placeId: number): number
	local url = BaseUrl .. "/api/place-metrics"
	local body = HttpService:JSONEncode({
		placeId = placeId,
	})
	local ok, res = pcall(function()
		return HttpService:RequestAsync({
			Url = url,
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json",
				["x-place-metrics-key"] = PlaceMetricsKey,
			},
			Body = body,
		})
	end)
	if not ok or not res or not res.Success or not res.Body then
		return 0
	end
	local data = HttpService:JSONDecode(res.Body)
	if typeof(data) ~= "table" or data.likes == nil then
		return 0
	end
	return tonumber(data.likes) or 0
end

function HttpProxyService.getGameVote()
	return getGameVoteFromTracker(placeId)
end

return HttpProxyService
