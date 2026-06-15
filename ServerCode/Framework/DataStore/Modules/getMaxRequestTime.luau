--!strict

--[[
	根据尝试次数、重试常数、重试分量和最坏情况下的合理估计时间，返回数据存储请求完成所需的估计时间。
	尝试次数、retryConstant、retryExponent 和合理的最坏情况估计值，返回数据存储请求完成所需的估计时间。
	DataStoreService 调用可能需要多长时间才能完成。

	有关重试的实际实现，请参阅 DataStoreWrapper 和 retryAsync。
--]]

local DATA_STORE_REQUEST_TIME = 3

local function getMaxRequestTime(numAttempts: number, retryConstant: number, retryExponent: number)
	local requestTime = 0

	for attemptNumber = 1, numAttempts do
		requestTime += DATA_STORE_REQUEST_TIME

		if attemptNumber > 1 then
			requestTime += retryConstant + (retryExponent ^ attemptNumber)
		end
	end

	return requestTime
end

return getMaxRequestTime
