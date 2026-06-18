--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameLogic = script.Parent
local Framework = ReplicatedStorage.ReplicatedCode.Framework

local Binder = require(Framework.Core.Binder)
local InputContextManager = require(Framework.Input.InputContextManager)
local UISetup = require(Framework.UI.UISetup)
local AttributeEnum = require(GameLogic.Shared.Enums.AttributeEnum)
local AutoAFK = require(Framework.Effects.AutoAFK)

local localPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() :: Player

local client = {}

-- 仅收录必须早期启动的核心单例；Controller / GUI 走约定扫描
local CLIENT_MODULES = {
	{ "Managers.SocialManager", { "Managers", "SocialManager" } },
	{ "Modules.LocalCharacter", { "Modules", "LocalCharacter" } },
}

local CONTROLLER_NAME_PATTERN = "Controller$"

local function findModule(pathParts: { string }): ModuleScript?
	local current: Instance = GameLogic
	for _, childName in ipairs(pathParts) do
		local child = current:FindFirstChild(childName)
		if not child then
			return nil
		end
		current = child
	end
	return if current:IsA("ModuleScript") then current else nil
end

local function callMethod(moduleName: string, moduleValue: any, methodName: string)
	local method = moduleValue[methodName]
	if type(method) ~= "function" then
		return
	end

	local success, err = xpcall(function()
		method(moduleValue)
	end, debug.traceback)
	if not success then
		warn(string.format("[ClientMain] %s.%s failed:\n%s", moduleName, methodName, tostring(err)))
	end
end

local function bootstrapModule(moduleName: string, moduleValue: any)
	if type(moduleValue.init) == "function" then
		callMethod(moduleName, moduleValue, "init")
	else
		callMethod(moduleName, moduleValue, "start")
		callMethod(moduleName, moduleValue, "listen")
		callMethod(moduleName, moduleValue, "setup")
	end
end

local function requireModule(moduleScript: ModuleScript): any?
	local success, moduleOrErr = xpcall(function()
		return require(moduleScript)
	end, debug.traceback)
	if not success then
		warn(string.format("[ClientMain] require failed: %s\n%s", moduleScript.Name, tostring(moduleOrErr)))
		return nil
	end
	return moduleOrErr
end

local function initializeInputContexts()
	local instances = ReplicatedStorage:FindFirstChild("Instances")
	local codeAssets = instances and instances:FindFirstChild("CodeAssets")
	local inputContexts = codeAssets and codeAssets:FindFirstChild("InputContexts")
	local contextsFolder = if inputContexts and inputContexts:IsA("Folder") then inputContexts else nil
	InputContextManager.init(contextsFolder)
end

local function startClientModule(moduleName: string, pathParts: { string })
	local moduleScript = findModule(pathParts)
	if not moduleScript then
		warn("[ClientMain] missing module: " .. moduleName)
		return
	end

	local moduleValue = requireModule(moduleScript)
	if moduleValue == nil then
		return
	end

	bootstrapModule(moduleName, moduleValue)
end

local function startControllers()
	local controllersFolder = GameLogic:FindFirstChild("Controllers")
	if not controllersFolder or not controllersFolder:IsA("Folder") then
		return
	end

	for _, child in controllersFolder:GetDescendants() do
		if child:IsA("ModuleScript") and child.Name:match(CONTROLLER_NAME_PATTERN) then
			local moduleValue = requireModule(child)
			if moduleValue ~= nil then
				bootstrapModule(child.Name, moduleValue)
			end
		end
	end
end

local function startGuisAsync()
	local guisFolder = GameLogic:FindFirstChild("Guis")
	if not guisFolder or not guisFolder:IsA("Folder") then
		return
	end

	task.spawn(function()
		UISetup.start(guisFolder, function()
			localPlayer:SetAttribute(AttributeEnum.UILoaded, true)
		end)
	end)
end

function client.start()
	initializeInputContexts()

	local VolumeManager = require(Framework.Managers.VolumeManager)
	VolumeManager.start()

	-- 启动自动 AFK 检测
	AutoAFK.new()

	local componentsFolder = GameLogic:FindFirstChild("Components")
	if componentsFolder and componentsFolder:IsA("Folder") then
		Binder.initialize(componentsFolder)
	end

	for _, moduleInfo in ipairs(CLIENT_MODULES) do
		startClientModule(moduleInfo[1] :: string, moduleInfo[2] :: { string })
	end

	startControllers()
	startGuisAsync()
end

return client
