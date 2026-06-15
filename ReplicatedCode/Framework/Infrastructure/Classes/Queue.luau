local Queue = {}
Queue.__index = Queue

export type ClassType = typeof(setmetatable(
	{} :: {
		_first: number,
		_last: number,
		_queue: {},
	
	},
	Queue
	))


function Queue.new()
	local self = setmetatable({}, Queue)
	
	self._first = 0
	self._last = -1
	self._queue = {}

	return self
end


function Queue:Destroy()
	self._first = nil
	self._last = nil
	self._queue = nil
end


-- Check if the queue is empty
function Queue:IsEmpty()
	return self._first > self._last
end

-- Add a value to the queue
function Queue:Enqueue(value)
	local last = self._last + 1
	self._last = last
	self._queue[last] = value
end

-- Remove a value from the queue
function Queue:Dequeue()
	local first = self._first
	if self:IsEmpty() then
		return nil
	end
	local value = self._queue[first]
	self._queue[first] = nil
	self._first = first + 1
	return value
end

-- 获取队列中的所有元素的副本
function Queue:Elements()
	local elements = {}
	local index = 1
	for i = self._first, self._last do
		elements[index] = self._queue[i]
		index = index + 1
	end
	return elements
end

-- Add a value to the top of the stack (Push)
function Queue:Push(value)
	self._last = self._last + 1
	self._queue[self._last] = value
end

-- Remove and return the top value from the stack (Pop)
function Queue:Pop()
	if self:IsEmpty() then
		return nil
	end
	local value = self._queue[self._last]
	self._queue[self._last] = nil
	self._last = self._last - 1
	return value
end

-- Get the first value without removing it from the queue
function Queue:Peek()
	if self:IsEmpty() then
		return nil
	end
	return self._queue[self._first]
end


function Queue:Size()
	return self._last - self._first + 1
end

-- Add a value with priority to the queue
function Queue:priorityEnqueue(value, priority)
	local newItem = {value = value, priority = priority or 0}

	if self:IsEmpty() then
		self._queue[self._first] = newItem
		self._last = self._first
	else
		local inserted = false
		for i = self._first, self._last do
			if self._queue[i].priority < priority then
				-- Shift items to make space for the new item
				for j = self._last, i, -1 do
					self._queue[j + 1] = self._queue[j]
				end
				self._queue[i] = newItem
				self._last = self._last + 1
				inserted = true
				break
			end
		end
		if not inserted then
			-- Insert at the end if no higher priority was found
			self._last = self._last + 1
			self._queue[self._last] = newItem
		end
	end
end

-- Remove a value from the queue
function Queue:priorityDequeue()
	local first = self._first
	if self:IsEmpty() then
		return nil
	end
	local value = self._queue[first].value
	self._queue[first] = nil
	self._first = first + 1
	return value
end




return Queue