--!strict

--[[
	按名称封装 RemoteEvent / RemoteFunction 的创建、等待和调用。
	Framework 自有 Remote 名称在 RemoteName 目录中维护；游戏层名称由启动入口注入。
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Framework = ReplicatedStorage:WaitForChild("ReplicatedCode"):WaitForChild("Framework")
local Utility = Framework:WaitForChild("Utility")
local Packages = Framework:WaitForChild("Packages")

local CreateRemotesFolders = require(script.CreateRemotesFolders)
local waitForAllRemotesAsync = require(script.WaitForAllRemotesAsync)
local getInstance = require(Utility.Instance.GetInstance)
local t = require(Packages.t)

local REMOTE_REPLICATION_TIMEOUT_SECONDS = 5
local REMOTE_FOLDER_PARENT = ReplicatedStorage
local REMOTE_FOLDER_NAME = "Remotes"

type NameTable = { [string]: string }
type TypeValidator = (...any) -> (boolean, string?)

local Network = {}
Network.t = t
Network.RemoteEvents = {} :: NameTable
Network.RemoteFunctions = {} :: NameTable

Network._started = false
Network._remoteFolder = nil :: Folder?
Network._remoteCache = {} :: { [string]: RemoteEvent | RemoteFunction }

local function configureRemoteNames(gameEventNames: NameTable?, gameFunctionNames: NameTable?)
	Network.RemoteEvents = gameEventNames or {}
	Network.RemoteFunctions = gameFunctionNames or {}
end

function Network.startServer(gameEventNames: NameTable?, gameFunctionNames: NameTable?)
	assert(RunService:IsServer(), "Network.startServer can only be called on the server")
	assert(not Network._started, "Network.startServer has already been called")
	Network._started = true

	configureRemoteNames(gameEventNames, gameFunctionNames)

	local remoteFolder = CreateRemotesFolders(REMOTE_FOLDER_NAME, Network.RemoteEvents, Network.RemoteFunctions)
	remoteFolder.Parent = REMOTE_FOLDER_PARENT
	Network._remoteFolder = remoteFolder
end

function Network.startClientAsync(gameEventNames: NameTable?, gameFunctionNames: NameTable?)
	assert(RunService:IsClient(), "Network.startClientAsync can only be called on the client")
	assert(not Network._started, "Network.startClientAsync has already been called")
	Network._started = true

	configureRemoteNames(gameEventNames, gameFunctionNames)

	local remoteFolder = REMOTE_FOLDER_PARENT:WaitForChild(REMOTE_FOLDER_NAME, REMOTE_REPLICATION_TIMEOUT_SECONDS) :: Folder
	assert(remoteFolder, string.format("Missing remote folder %s. Did the server initialize Network?", REMOTE_FOLDER_NAME))

	waitForAllRemotesAsync(remoteFolder, REMOTE_REPLICATION_TIMEOUT_SECONDS, Network.RemoteEvents, Network.RemoteFunctions)
	Network._remoteFolder = remoteFolder
end

function Network.connectEvent(eventName: string, callback: (...any) -> ...any, typeValidator: TypeValidator?)
	local remoteEvent = Network._getRemoteEvent(eventName)

	local function wrappedCallback(...)
		if typeValidator then
			local success: boolean
			local err: string?

			if RunService:IsServer() then
				local args = { ... }
				local player = args[1]
				local isPlayer, playerErr = t.instanceIsA("Player")(player)

				if not isPlayer then
					success, err = false, "First argument must be a Player: " .. tostring(playerErr)
				else
					success, err = typeValidator(select(2, ...))
				end
			else
				success, err = typeValidator(...)
			end

			if not success then
				warn(string.format("[Network] Type check failed for event '%s': %s", eventName, err or "unknown error"))
				return
			end
		end

		callback(...)
	end

	if RunService:IsServer() then
		return remoteEvent.OnServerEvent:Connect(wrappedCallback)
	else
		return remoteEvent.OnClientEvent:Connect(wrappedCallback)
	end
end

function Network.bindFunction(functionName: string, callback: (...any) -> ...any, typeValidator: TypeValidator?)
	local remoteFunction = Network._getRemoteFunction(functionName)

	local function wrappedCallback(...)
		if typeValidator then
			local success: boolean
			local err: string?

			if RunService:IsServer() then
				local args = { ... }
				local player = args[1]
				local isPlayer, playerErr = t.instanceIsA("Player")(player)

				if not isPlayer then
					success, err = false, "First argument must be a Player: " .. tostring(playerErr)
				else
					success, err = typeValidator(select(2, ...))
				end
			else
				success, err = typeValidator(...)
			end

			if not success then
				warn(string.format("[Network] Type check failed for function '%s': %s", functionName, err or "unknown error"))
				return nil
			end
		end

		return callback(...)
	end

	if RunService:IsServer() then
		remoteFunction.OnServerInvoke = wrappedCallback
	else
		remoteFunction.OnClientInvoke = wrappedCallback
	end
end

function Network.fireServer(eventName: string, ...: any)
	assert(RunService:IsClient(), "Network.fireServer can only be called on the client")

	local remoteEvent = Network._getRemoteEvent(eventName)
	remoteEvent:FireServer(...)
end

function Network.fireClient(eventName: string, player: Player, ...: any)
	assert(RunService:IsServer(), "Network.fireClient can only be called on the server")

	local remoteEvent = Network._getRemoteEvent(eventName)
	remoteEvent:FireClient(player, ...)
end

function Network.fireClientFor(eventName: string, players: { Player }, ...: any)
	assert(RunService:IsServer(), "Network.fireClientFor can only be called on the server")

	local remoteEvent = Network._getRemoteEvent(eventName)
	for _, player in pairs(players) do
		remoteEvent:FireClient(player, ...)
	end
end

function Network.fireAllClients(eventName: string, ...: any)
	assert(RunService:IsServer(), "Network.fireAllClients can only be called on the server")

	local remoteEvent = Network._getRemoteEvent(eventName)
	remoteEvent:FireAllClients(...)
end

function Network.fireClientsFilter(eventName: string, filter: (Player) -> boolean, ...: any)
	assert(RunService:IsServer(), "Network.fireClientsFilter can only be called on the server")

	local remoteEvent = Network._getRemoteEvent(eventName)
	for _, player in ipairs(Players:GetPlayers()) do
		if not filter(player) then
			remoteEvent:FireClient(player, ...)
		end
	end
end

function Network.fireAllClientsExcept(eventName: string, excludePlayer: Player, ...: any)
	assert(RunService:IsServer(), "Network.fireAllClientsExcept can only be called on the server")

	local remoteEvent = Network._getRemoteEvent(eventName)
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= excludePlayer then
			remoteEvent:FireClient(player, ...)
		end
	end
end

function Network.invokeServerAsync(functionName: string, ...: any): (boolean, ...any)
	assert(RunService:IsClient(), "Network.invokeServerAsync can only be called on the client")

	local remoteFunction = Network._getRemoteFunction(functionName)
	return pcall(remoteFunction.InvokeServer, remoteFunction, ...)
end

function Network.invokeClientAsync(functionName: string, player: Player, ...: any): (boolean, ...any)
	assert(RunService:IsServer(), "Network.invokeClientAsync can only be called on the server")

	local remoteFunction = Network._getRemoteFunction(functionName)
	return pcall(remoteFunction.InvokeClient, remoteFunction, player, ...)
end

function Network._getRemoteEvent(eventName: string): RemoteEvent
	assert(Network._remoteFolder, "Network setup not complete")

	local cached = Network._remoteCache[eventName]
	if cached then
		return cached :: RemoteEvent
	end

	local eventsFolder = getInstance(Network._remoteFolder, "RemoteEvents") :: Folder
	local remoteEvent = eventsFolder:FindFirstChild(eventName) :: RemoteEvent?

	if not remoteEvent then
		if RunService:IsServer() then
			remoteEvent = Instance.new("RemoteEvent")
			remoteEvent.Name = eventName
			remoteEvent.Parent = eventsFolder
		else
			remoteEvent = eventsFolder:WaitForChild(eventName, REMOTE_REPLICATION_TIMEOUT_SECONDS) :: RemoteEvent?
			assert(remoteEvent, "RemoteEvent not found: " .. eventName)
		end
	end

	Network._remoteCache[eventName] = remoteEvent
	return remoteEvent
end

function Network._getRemoteFunction(functionName: string): RemoteFunction
	assert(Network._remoteFolder, "Network setup not complete")

	local cached = Network._remoteCache[functionName]
	if cached then
		return cached :: RemoteFunction
	end

	local functionsFolder = getInstance(Network._remoteFolder, "RemoteFunctions") :: Folder
	local remoteFunction = functionsFolder:FindFirstChild(functionName) :: RemoteFunction?

	if not remoteFunction then
		if RunService:IsServer() then
			remoteFunction = Instance.new("RemoteFunction")
			remoteFunction.Name = functionName
			remoteFunction.Parent = functionsFolder
		else
			remoteFunction = functionsFolder:WaitForChild(functionName, REMOTE_REPLICATION_TIMEOUT_SECONDS) :: RemoteFunction?
			assert(remoteFunction, "RemoteFunction not found: " .. functionName)
		end
	end

	Network._remoteCache[functionName] = remoteFunction
	return remoteFunction
end

return Network
