--[=[
		@class Loader

	Loader 模块负责 require 所有子级或后代 ModuleScript。同时包含一些实用函数，
	辅助在单脚本环境中加载和启动模块。
    ...
	```lua
	local MyModules = ReplicatedStorage.MyModules
	Loader.SpawnAll(
		Loader.LoadDescendants(MyModules, Loader.MatchesName("Service$")),
		"OnStart"
	)
	```
]=]
local RunService = game:GetService("RunService")

local Loader = {}
local Registry = {} -- 用于存储所有加载成功的模块及其状态

--[=[
	@within Loader
	@type PredicateFn (module: ModuleScript) -> boolean
	Predicate function type.
]=]
type PredicateFn = (module: ModuleScript) -> boolean

--[=[
	Requires all children ModuleScripts.

	If a `predicate` function is provided, then the module will only
	be loaded if the predicate returns `true` for the the given
	ModuleScript.

	```lua
	-- Load all ModuleScripts directly under MyModules:
	Loader.LoadChildren(ReplicatedStorage.MyModules)

	-- Load all ModuleScripts directly under MyModules if they have names ending in 'Service':
	Loader.LoadChildren(ReplicatedStorage.MyModules, function(moduleScript)
		return moduleScript.Name:match("Service$") ~= nil
	end)
	```
]=]
function Loader.LoadChildren(parent: Instance, predicate: PredicateFn?): { [string]: any }
	local modules: { [string]: any } = {}
	for _, child in parent:GetChildren() do
		if child:IsA("ModuleScript") then
			if predicate and not predicate(child :: ModuleScript) then
				continue
			end
			if modules[child.Name] then
				if RunService:IsStudio() then
					warn(
						string.format(
							"[Loader] 同名模块冲突：'%s' 下存在重复的 '%s'，后者会覆盖前者",
							parent.Name,
							child.Name
						)
					)
				else
					warn("[Loader] 检测到同名模块冲突：后者会覆盖前者")
				end
			end
			local m = (require :: any)(child)
			modules[child.Name] = m
		end
	end
	return modules
end

--[=[
	Requires all descendant ModuleScripts.

	If a `predicate` function is provided, then the module will only
	be loaded if the predicate returns `true` for the the given
	ModuleScript.

	```lua
	-- Load all ModuleScripts under MyModules:
	Loader.LoadDescendants(ReplicatedStorage.MyModules)

	-- Load all ModuleScripts under MyModules if they have names ending in 'Service':
	Loader.LoadDescendants(ReplicatedStorage.MyModules, function(moduleScript)
		return moduleScript.Name:match("Service$") ~= nil
	end)
]=]
function Loader.LoadDescendants(parent: Instance, predicate: PredicateFn?): { [string]: any }
	local modules: { [string]: any } = {}
	for _, descendant in parent:GetDescendants() do
		if descendant:IsA("ModuleScript") then
			if predicate and not predicate(descendant :: ModuleScript) then
				continue
			end
			if modules[descendant.Name] then
				if RunService:IsStudio() then
					warn(
						string.format(
							"[Loader] 同名模块冲突：'%s' 下存在重复的 '%s'，后者会覆盖前者",
							parent.Name,
							descendant.Name
						)
					)
				else
					warn("[Loader] 检测到同名模块冲突：后者会覆盖前者")
				end
			end
			local m = (require :: any)(descendant)
			modules[descendant.Name] = m
		end
	end
	return modules
end

--[=[
	A commonly-used predicate in the `LoadChildren` and `LoadDescendants`
	functions is one to match names. Therefore, the `MatchesName` utility
	function provides a quick way to create such predicates.

	```lua
	Loader.LoadDescendants(ReplicatedStorage.MyModules, Loader.MatchesName("Service$"))
	```
]=]
function Loader.MatchesName(matchName: string): (module: ModuleScript) -> boolean
	return function(moduleScript: ModuleScript): boolean
		return moduleScript.Name:match(matchName) ~= nil
	end
end

--[=[
	Utility function for spawning a specific method in all given modules.
	If a module does not contain the specified method, it is simply
	skipped. Methods are called with `task.spawn` internally.

	For example, if the modules are expected to have an `OnStart()` method,
	then `SpawnAll()` could be used to start all of them directly after
	they have been loaded:

	```lua
	local MyModules = ReplicatedStorage.MyModules

	-- Load all modules under MyModules and then call their OnStart methods:
	Loader.SpawnAll(Loader.LoadDescendants(MyModules), "OnStart")

	-- Same as above, but only loads modules with names that end with Service:
	Loader.SpawnAll(
		Loader.LoadDescendants(MyModules, Loader.MatchesName("Service$")),
		"OnStart"
	)
	```
]=]
function Loader.SpawnAll(loadedModules: { [string]: any }, methodName: string)
	local totalModules = 0
	for name, mod in loadedModules do
		totalModules += 1
		local method = mod[methodName]
		if type(method) == "function" then
			task.spawn(function()
				local start = os.clock()
				debug.setmemorycategory(name)

				local success, err = xpcall(function()
					method(mod)
				end, debug.traceback)

				local duration = os.clock() - start
				Registry[name] = Registry[name] or {}
				Registry[name][methodName] = {
					success = success,
					duration = duration,
					error = err,
				}

				if not success then
					if RunService:IsStudio() then
						warn(string.format("[Loader] Failed to call %s on %s: %s", methodName, name, tostring(err)))
					else
						warn(string.format("[Loader] Failed to call %s: %s", methodName, tostring(err)))
					end
				elseif RunService:IsStudio() and duration > 0.1 then -- 如果耗时超过 0.1s 则在 Studio 环境下记录警告
					warn(string.format("[Loader] %s:%s took %.4fs", name, methodName, duration))
				end
			end)
		end
	end

	if RunService:IsStudio() then
		print(string.format("[Loader] Spawned %d modules for method %s", totalModules, methodName))
	end
end

--[=[
	Sequential version of SpawnAll. Calls the method on all modules one by one.
	Useful for Init phase where order might not matter but parallelism is not desired.
]=]
function Loader.InitAll(loadedModules: { [string]: any }, methodName: string)
	local startTime = os.clock()
	local count = 0

	for name, mod in loadedModules do
		local method = mod[methodName]
		if type(method) == "function" then
			local start = os.clock()
			debug.setmemorycategory(name)

			local success, err = xpcall(function()
				method(mod)
			end, debug.traceback)

			local duration = os.clock() - start
			Registry[name] = Registry[name] or {}
			Registry[name][methodName] = {
				success = success,
				duration = duration,
				error = err,
			}

			if not success then
				if RunService:IsStudio() then
					warn(string.format("[Loader] Failed to init %s on %s: %s", methodName, name, tostring(err)))
				else
					warn(string.format("[Loader] Failed to init %s: %s", methodName, tostring(err)))
				end
			end
			count += 1
		end
	end

	local totalDuration = os.clock() - startTime
	if RunService:IsStudio() then
		print(string.format("[Loader] Finished %s for %d modules in %.4fs", methodName, count, totalDuration))
	end
end

--[=[
	并行版 InitAll。所有模块的方法同时以 task.spawn 启动，等全部完成后才返回。
	适用于各模块 init 之间无依赖关系、但调用方需等待全部完成的场景（如 GUI 初始化）。
	总耗时 ≈ 最慢单个模块，而非所有模块之和。
]=]
function Loader.ParallelInit(loadedModules: { [string]: any }, methodName: string)
	local startTime = os.clock()

	-- 统计有该方法的模块数量
	local pending = 0
	for _, mod in loadedModules do
		if type(mod[methodName]) == "function" then
			pending += 1
		end
	end

	if pending == 0 then
		if RunService:IsStudio() then
			print(string.format("[Loader] Finished %s for 0 modules in 0.0000s (parallel)", methodName))
		end
		return
	end

	local finished = 0
	local allSpawned = false
	local thread = coroutine.running()

	for name, mod in loadedModules do
		local method = mod[methodName]
		if type(method) == "function" then
			task.spawn(function()
				local start = os.clock()
				debug.setmemorycategory(name)

				local success, err = xpcall(function()
					method(mod)
				end, debug.traceback)

				local duration = os.clock() - start
				Registry[name] = Registry[name] or {}
				Registry[name][methodName] = {
					success = success,
					duration = duration,
					error = err,
				}

				if not success then
					if RunService:IsStudio() then
						warn(string.format("[Loader] Failed to init %s on %s: %s", methodName, name, tostring(err)))
					else
						warn(string.format("[Loader] Failed to init %s: %s", methodName, tostring(err)))
					end
				elseif RunService:IsStudio() then
					print(string.format("[Loader:ParallelInit] %s took %.4fs", name, duration))
				end

				finished += 1
				-- allSpawned 确保主线程已到达 yield，再唤醒
				if allSpawned and finished >= pending then
					task.spawn(thread)
				end
			end)
		end
	end

	-- 若所有 task.spawn 同步完成（无 yield），则无需挂起
	allSpawned = true
	if finished < pending then
		coroutine.yield()
	end

	local totalDuration = os.clock() - startTime
	if RunService:IsStudio() then
		print(string.format("[Loader] Finished %s for %d modules in %.4fs (parallel)", methodName, pending, totalDuration))
	end
end

--[=[
	Returns the registry of all loaded modules and their lifecycle status.
	Useful for developer tools.
]=]
function Loader.GetRegistry()
	return Registry
end

return Loader
