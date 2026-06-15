--!strict

--[[
	Wait in parallel for all RemoteEvents and RemoteFunctions defined in RemoteNames to
	replicate into the remoteFolder.

	Used to ensure all remotes exist before the client Network module finishes initializing.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sift = require(ReplicatedStorage.ReplicatedCode.Framework.Packages.Sift)
local RemoteEventName = require(script.Parent.RemoteName.RemoteEventName)
local RemoteFunctionName = require(script.Parent.RemoteName.RemoteFunctionName)
local RemoteFolderName = require(script.Parent.RemoteFolderName)

type NameTable = { [string]: string }

local function waitForAllRemotesAsync(
	remoteFolder: Instance,
	timeoutSeconds: number,
	extraEventNames: NameTable?,
	extraFunctionNames: NameTable?
)
	local remoteEventsFolder = remoteFolder:FindFirstChild(RemoteFolderName.RemoteEvents) :: Folder
	local remoteFunctionsFolder = remoteFolder:FindFirstChild(RemoteFolderName.RemoteFunctions) :: Folder

	local remoteEvents: { string } = Sift.Dictionary.values(RemoteEventName :: any)
	local remoteFunctions: { string } = Sift.Dictionary.values(RemoteFunctionName :: any)

	if extraEventNames then
		for _, name in pairs(Sift.Dictionary.values(extraEventNames :: any) :: { string }) do
			table.insert(remoteEvents, name)
		end
	end
	if extraFunctionNames then
		for _, name in pairs(Sift.Dictionary.values(extraFunctionNames :: any) :: { string }) do
			table.insert(remoteFunctions, name)
		end
	end

	local success = true
	local function search(names: { string }, folder: Folder)
		for _, remoteName in ipairs(names) do
			local remote = folder:WaitForChild(remoteName, timeoutSeconds)
			if not remote then
				success = false
				break
			end
		end
	end

	search(remoteEvents, remoteEventsFolder)
	search(remoteFunctions, remoteFunctionsFolder)

	assert(success, "Network could not find all remotes. Did the client Network module initialize before the server?")
end

return waitForAllRemotesAsync
