--!strict

--[[
		调用并重试给定函数的函数，最多可重试 maxAttempts 次。
	该函数会在两次重试之间等待 pauseConstant + (pauseExponent ^ numAttempts)，以进行指数式渐进后退。
	使用 functionCallHandler（默认：pcall）进行调用。
	进行调用，并返回调用结果（成功、错误信息或......）。
--]]

type Function = (...any) -> ...any
export type FunctionHandler = (...any) -> (boolean, ...any)

local function retryAsync(
	func: Function,
	maxAttempts: number, -- 最大尝试次数
	optionalPauseConstant: number?, -- 可选暂停常数
	optionalPauseExponent: number?, -- 可选暂停指数
	optionalFunctionCallHandler: ((Function) -> (boolean, ...any))? -- 可选函数调用处理程序
): (boolean, ...any)
	-- 使用单独的变量来满足类型检查程序的要求
	local pauseConstant: number = optionalPauseConstant or 0
	local pauseExponent: number = optionalPauseExponent or 0
	local functionCallHandler: FunctionHandler = optionalFunctionCallHandler or pcall

	local attempts = 0
	local success: boolean = false
	local result: { any } = {}

	while attempts < maxAttempts do
		attempts = attempts + 1

		local returnValues: { any }

		returnValues = { functionCallHandler(func) }

		success = table.remove(returnValues, 1) :: boolean
		result = returnValues

		if success then
			break
		end

		local pauseTime = pauseConstant + (pauseExponent ^ attempts)

		if attempts < maxAttempts then
			task.wait(pauseTime)
		end
	end

	if success then
		return success, table.unpack(result)
	else
		local errorMessage = not success and result[1] :: any or nil
		return success, errorMessage :: any
	end
end

return retryAsync
