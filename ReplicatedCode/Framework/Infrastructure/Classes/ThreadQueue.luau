--!strict

--[[
ThreadQueue 是一个任务调度器和速率限制器，它允许回调排队等待执行，在请求线程
	直到回调返回。

	ThreadQueue 提供了与 NodeJS 模块 Bottleneck（https://www.npmjs.com/package/bottleneck）类似的功能，但它通过 coroutity 公开了其调度功能。
	其调度功能是通过 coroutines 而不是 promises 来实现的。
--]]

local ThreadQueue = {}
ThreadQueue.__index = ThreadQueue

export type ClassType = typeof(setmetatable(
	{} :: {
		_queue: { QueueEntry },
		_queueRunning: boolean,
		_timeBetween: number,
		_maxQueueLength: number,
		_enableConcurrency: boolean,
	},
	ThreadQueue
))

type Callback = (...any) -> ...any

type QueueEntry = {
	thread: thread,
	callback: Callback,
}

function ThreadQueue.new(timeBetween: number?, maxQueueLength: number?, enableConcurrency: boolean?): ClassType
	local self = {
		_queue = {},
		_queueRunning = false,
		_timeBetween = (timeBetween or 0),
		_maxQueueLength = (maxQueueLength or math.huge),
		_enableConcurrency = enableConcurrency and true or false,
	}
	setmetatable(self, ThreadQueue)

	return self
end

function ThreadQueue.submitAsync(self: ClassType, callback: Callback)
	if #self._queue > self._maxQueueLength then
		return false, string.format("Queue is at capacity (%i)", self._maxQueueLength)
	end

	local queueEntry: QueueEntry = {
		thread = coroutine.running(),
		callback = callback,
	}

	table.insert(self._queue, queueEntry)

	self:_startQueue()

	return coroutine.yield()
end

function ThreadQueue.getLength(self: ClassType): number
	return #self._queue
end

function ThreadQueue.skipToLastEnqueued(self: ClassType)
	-- 此方法不会跳过当前正在执行的请求，但会移除
	-- 从队列中移除所有待处理的请求，但最近提交的请求除外。
	if #self._queue > 1 then
		local lastEnqueuedEntry = self._queue[#self._queue]
		self._queue = { lastEnqueuedEntry }
	end
end

function ThreadQueue._startQueue(self: ClassType)
	-- 等待下一个恢复周期，以便请求线程有时间先让步
	task.defer(function()
		if self._queueRunning then
			return
		end
		self._queueRunning = true

		while #self._queue > 0 do
			self:_popQueueAsync()

			if self._timeBetween > 0 then
				task.wait(self._timeBetween)
			end
		end

		self._queueRunning = false
	end)
end

function ThreadQueue._popQueueAsync(self: ClassType)
	local entry = table.remove(self._queue, 1) :: QueueEntry

	local function execute()
		-- 该回调可以产生结果。请注意，回调是在此线程上同步调用的。
		-- task.spawn 用于使用回调的 pcall 结果恢复调用线程。
		task.spawn(entry.thread, pcall(entry.callback))
	end

	-- 如果启用了并发功能，我们在等待回调返回时就不会让出队列
	if self._enableConcurrency then
		-- 使用 spawn 调用执行，这样 entry.callback 就不会阻止我们继续执行了
		task.spawn(execute)
	else
		execute()
	end
end

return ThreadQueue
