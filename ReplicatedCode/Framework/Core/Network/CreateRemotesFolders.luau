--!strict

--[[
	Creates folders for RemoteFunctions and RemoteEvents used by
	Network. These folders are then populated with new RemoteEvents
	and RemoteFunctions for each name specified in the RemoteNames constants module.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEventName = require(script.Parent.RemoteName.RemoteEventName)
local RemoteFunctionName = require(script.Parent.RemoteName.RemoteFunctionName)
local RemoteFolderName = require(script.Parent.RemoteFolderName)
local createInstanceTree = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Instance.CreateInstanceTree)
local getInstance = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Instance.GetInstance)
local t = require(ReplicatedStorage.ReplicatedCode.Framework.Packages.t)


type PropertiesTable = { [string]: any }
type NameTable = { [string]: string }

local RemoteEventsName = (RemoteFolderName :: any).RemoteEvents
local RemoteFunctionsName = (RemoteFolderName :: any).RemoteFunctions

local function createRemotes(remoteFolder: Folder, extraEventNames: NameTable?, extraFunctionNames: NameTable?)
	local remoteEventsFolder: Folder = (getInstance(remoteFolder, RemoteEventsName) :: any) :: Folder
	local isUnreliable = t.match("Unreliable")

	local function createEvent(eventName: string)
		if isUnreliable(eventName) then
			local remoteEvent = Instance.new("UnreliableRemoteEvent")
			remoteEvent.Name = eventName
			remoteEvent.Parent = remoteEventsFolder
		else
			local remoteEvent = Instance.new("RemoteEvent")
			remoteEvent.Name = eventName
			remoteEvent.Parent = remoteEventsFolder
		end
	end

	for eventName in pairs(RemoteEventName :: { [string]: any }) do
		createEvent(eventName)
	end
	if extraEventNames then
		for eventName in pairs(extraEventNames :: { [string]: any }) do
			if not remoteEventsFolder:FindFirstChild(eventName) then
				createEvent(eventName)
			end
		end
	end

	local remoteFunctionsFolder: Folder = (getInstance(remoteFolder, RemoteFunctionsName) :: any) :: Folder

	for functionName in pairs(RemoteFunctionName :: { [string]: any }) do
		local remoteFunction = Instance.new("RemoteFunction")
		remoteFunction.Name = functionName
		remoteFunction.Parent = remoteFunctionsFolder
	end
	if extraFunctionNames then
		for functionName in pairs(extraFunctionNames :: { [string]: any }) do
			if not remoteFunctionsFolder:FindFirstChild(functionName) then
				local remoteFunction = Instance.new("RemoteFunction")
				remoteFunction.Name = functionName
				remoteFunction.Parent = remoteFunctionsFolder
			end
		end
	end
end

local function createRemotesFolders(rootFolderName: string, extraEventNames: NameTable?, extraFunctionNames: NameTable?): Folder
	local folder = createInstanceTree({
		className = "Folder",
		properties = {
			Name = rootFolderName,
		},
		children = {
			{
				className = "Folder",
				properties = {
					Name = RemoteFunctionsName,
				} :: PropertiesTable,
			},
			{
				className = "Folder",
				properties = {
					Name = RemoteEventsName,
				} :: PropertiesTable,
			},
		},
	})

	createRemotes(folder, extraEventNames, extraFunctionNames)

	return folder
end

return createRemotesFolders

