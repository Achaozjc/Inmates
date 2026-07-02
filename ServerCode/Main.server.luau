--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ReplicatedCode = ReplicatedStorage:WaitForChild("ReplicatedCode")
local ServerCode = ServerScriptService:WaitForChild("ServerCode")
local Framework = ReplicatedCode:WaitForChild("Framework")
local GameLogic = ServerCode:WaitForChild("GameLogic")
local SharedGameLogic = ReplicatedCode:WaitForChild("GameLogic")

local Binder = require(Framework.Core.Binder)
local Network = require(Framework.Core.Network)
local safePlayerAdded = require(Framework.Utility.Player.SafePlayerAdded)
local PlayerDataServer = require(ServerCode.Framework.DataStore.PlayerData.PlayerDataServer)
local ReceiptProcessor = require(ServerCode.Framework.DataStore.PlayerData.ReceiptProcessor)

local RemoteEventKey = require(SharedGameLogic.SharedConstants.Keys.RemoteEventKey)
local RemoteFunctionKey = require(SharedGameLogic.SharedConstants.Keys.RemoteFunctionKey)
local DefaultPlayerData = require(GameLogic.DataStore.DefaultPlayerData)
local CodeDataServer = require(GameLogic.DataStore.CodeDataServer)
local GameSetting = require(SharedGameLogic.Shared.Settings.GameSetting)
local PlayerService = require(GameLogic.Service.Sync.PlayerService)
local registerDevProducts = require(GameLogic.registerDevProducts)
local TeleportManager = require(ServerCode.Framework.Managers.TeleportManager)

local function getModule(root: Instance, ...: string): ModuleScript
	local current = root
	for _, childName in ipairs({ ... }) do
		current = current:WaitForChild(childName)
	end
	return current :: ModuleScript
end

local function startLoadedService(serviceName: string, service: any)
	for _, methodName in ipairs({ "start", "listen" }) do
		local method = service[methodName]
		if type(method) == "function" then
			local success, err = xpcall(function()
				method()
			end, debug.traceback)
			if not success then
				warn(string.format("[Main] %s.%s failed:\n%s", serviceName, methodName, tostring(err)))
			end
		end
	end
end

local function startService(serviceName: string, moduleScript: ModuleScript)
	local success, serviceOrErr = xpcall(function()
		return require(moduleScript)
	end, debug.traceback)
	if not success then
		warn(string.format("[Main] require service failed: %s\n%s", serviceName, tostring(serviceOrErr)))
		return
	end

	startLoadedService(serviceName, serviceOrErr)
end

local function startServerComponents()
	local componentsFolder = GameLogic:FindFirstChild("Components")
	if componentsFolder and componentsFolder:IsA("Folder") then
		Binder.initialize(componentsFolder)
	end
end

local function onPlayerAdded(player: Player)
	PlayerDataServer.waitForDataLoadAsync(player)
	PlayerService.refreshData(player)
	PlayerService.syncPlayerAttributes(player)
end

local function onPlayerRemoving(player: Player)
	PlayerDataServer.onPlayerRemovingAsync(player)
end

Network.startServer(RemoteEventKey, RemoteFunctionKey)
TeleportManager.start()
PlayerDataServer.start(GameSetting.DATA_STORE_NAME, { ReceiptProcessor.receiptHistoryValueName }, DefaultPlayerData)
registerDevProducts()
ReceiptProcessor.start()

startService("RefreshService", getModule(GameLogic, "Service", "Sync", "RefreshService"))
startLoadedService("PlayerService", PlayerService)
startService("RewardService", getModule(GameLogic, "Service", "Sync", "RewardService"))
startService("DayNightService", getModule(GameLogic, "Service", "DayNightService"))
startService("WeatherService", getModule(GameLogic, "Service", "WeatherService"))
startService("StoreService", getModule(GameLogic, "Service", "Sync", "StoreService"))
startService("SpinService", getModule(GameLogic, "Service", "Sync", "SpinService"))
startService("SeasonPassService", getModule(GameLogic, "Service", "Sync", "SeasonPassService"))
startService("OfflineIncomeService", getModule(GameLogic, "Service", "Sync", "OfflineIncomeService"))
startService("LeaderboardService", getModule(GameLogic, "Service", "Sync", "LeaderboardService"))
startService("LeaderboardRewardService", getModule(GameLogic, "Service", "Sync", "LeaderboardRewardService"))
require(getModule(GameLogic, "Components", "LeaderboardScreen")).bootstrapWorkspace()
startService("ServerBoostService", getModule(GameLogic, "Service", "ServerBoostService"))
startService("VoteService", getModule(GameLogic, "Service", "Sync", "VoteService"))
CodeDataServer.start()
startService("CodeService", getModule(GameLogic, "Service", "Sync", "CodeService"))
startLoadedService("EventService", require(getModule(GameLogic, "Service", "Sync", "EventService")))
startService("BaseAssignmentService", getModule(GameLogic, "Service", "AxeTycoon", "BaseAssignmentService"))
startService("AxeService", getModule(GameLogic, "Service", "AxeTycoon", "AxeService"))
startService("ChestProductionService", getModule(GameLogic, "Service", "AxeTycoon", "ChestProductionService"))
startService("ChestService", getModule(GameLogic, "Service", "AxeTycoon", "ChestService"))
startService("WoodProductionService", getModule(GameLogic, "Service", "AxeTycoon", "WoodProductionService"))
startService("WoodCarryService", getModule(GameLogic, "Service", "AxeTycoon", "WoodCarryService"))
startService("WoodMultiplierService", getModule(GameLogic, "Service", "AxeTycoon", "WoodMultiplierService"))
startService("CashMultiplierService", getModule(GameLogic, "Service", "AxeTycoon", "CashMultiplierService"))
startService("ProcessorService", getModule(GameLogic, "Service", "AxeTycoon", "ProcessorService"))
startService("CollectMoneyService", getModule(GameLogic, "Service", "AxeTycoon", "CollectMoneyService"))
startService("ProcessorUpgradeService", getModule(GameLogic, "Service", "AxeTycoon", "ProcessorUpgradeService"))
startService("GamepassService", getModule(GameLogic, "Service", "AxeTycoon", "GamepassService"))
startService("GroupRewardService", getModule(GameLogic, "Service", "AxeTycoon", "GroupRewardService"))
startService("OfflineWoodService", getModule(GameLogic, "Service", "AxeTycoon", "OfflineWoodService"))
startService("TutorialService", getModule(GameLogic, "Service", "AxeTycoon", "TutorialService"))
startService("CharacterTagService", getModule(GameLogic, "Service", "CharacterTagService"))
startServerComponents()

safePlayerAdded(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

game:BindToClose(function()
	ReplicatedStorage:SetAttribute("ShuttingDown", true)
end)
