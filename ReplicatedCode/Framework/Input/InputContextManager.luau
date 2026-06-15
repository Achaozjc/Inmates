--!strict
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local InputContextManager = {
	contexts = {} :: { [string]: InputContext },
	_contextsFolder = nil :: Folder?,
	_initialized = false
}

local function remountContexts()
	local contextsFolder = InputContextManager._contextsFolder
	if not contextsFolder then
		return
	end

	local playerScripts = player:WaitForChild("PlayerScripts")
	InputContextManager.contexts = {}

	for _, child in contextsFolder:GetChildren() do
		if child:IsA("InputContext") then
			local context = child:Clone()
			context.Enabled = false
			context.Parent = playerScripts
			InputContextManager.contexts[context.Name] = context
		end
	end
end

-- 初始化并挂载指定文件夹下的所有 InputContext
function InputContextManager.init(contextsFolder: Folder?)
	if InputContextManager._initialized then return end

	InputContextManager._contextsFolder = contextsFolder
	remountContexts()

	InputContextManager._initialized = true
end

-- 获取已注册的 InputContext
function InputContextManager.get(name: string): InputContext?
	if not InputContextManager._initialized then
		warn("InputContextManager not initialized! Call init(folder) first.")
		return nil
	end
	local context = InputContextManager.contexts[name]
	if context and context.Parent == nil and InputContextManager._contextsFolder then
		-- 角色重生后若上下文被清理，则自动重新挂载一次
		remountContexts()
		context = InputContextManager.contexts[name]
	end
	return context
end

-- 获取指定的 InputAction
function InputContextManager.getAction(contextName: string, actionName: string): InputAction?
	local context = InputContextManager.get(contextName)
	if context then
		return context:FindFirstChild(actionName) :: InputAction?
	end
	return nil
end

-- 启用指定的 InputContext
function InputContextManager.enable(name: string)
	local context = InputContextManager.get(name)
	if context then
		context.Enabled = true
	else
		warn("InputContextManager: Cannot enable. Context not found -> " .. tostring(name))
	end
end

-- 禁用指定的 InputContext
function InputContextManager.disable(name: string)
	local context = InputContextManager.get(name)
	if context then
		context.Enabled = false
	end
end


return InputContextManager
