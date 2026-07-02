--!strict
--[[
	LeaderboardScreen
	世界排行榜展示屏 Binder 组件（服务端）。
	标签：LeaderboardScreen —— 给排行榜 Screen Part 打上该 CollectionService 标签即可。

	实例要求：
	  · 位于 Workspace.World.LeaderBoard 下（或任意世界位置）
	  · 设置 Attribute「OrderedStoreName」为 Cash / PlayTime / TotalMerges
	    （未设置时按实例名映射，见 BOARD_ID_ALIASES）
	  · 预制体：ReplicatedStorage.Instances.Prefabs.Gui
	    （LeaderboardSurfaceGui / BoardListTemplate / LeaderBoardTemplate）
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Signal = require(ReplicatedStorage.ReplicatedCode.Framework.Packages.Signal)
local TagCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.TagCategory)
local OrderedStoreNames = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.OrderedStoreNames)
local LeaderboardConfig = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Configs.LeaderboardConfig)
local LeaderboardDisplay = require(script.Parent.Parent.Modules.Leaderboard.LeaderboardDisplay)
local LeaderboardScreenRegistry = require(script.Parent.Parent.Modules.Leaderboard.LeaderboardScreenRegistry)

-- 实例名 / Attribute 别名 → 榜单 boardId
local BOARD_ID_ALIASES: { [string]: string } = {
	["Lifetime Cash"] = OrderedStoreNames.Cash,
	["Cash"] = OrderedStoreNames.Cash,
	["Playtime"] = OrderedStoreNames.PlayTime,
	["Play Time"] = OrderedStoreNames.PlayTime,
	["PlayTime"] = OrderedStoreNames.PlayTime,
	["Total Merges"] = OrderedStoreNames.TotalMerges,
	["TotalMerges"] = OrderedStoreNames.TotalMerges,
	[OrderedStoreNames.Cash] = OrderedStoreNames.Cash,
	[OrderedStoreNames.PlayTime] = OrderedStoreNames.PlayTime,
	[OrderedStoreNames.TotalMerges] = OrderedStoreNames.TotalMerges,
}

local LeaderboardScreen = {}
LeaderboardScreen.__index = LeaderboardScreen

export type ClassType = typeof(setmetatable({} :: {
	_instance: Instance,
	leadboard: LeaderboardDisplay.ClassType,
	surfaceGui: SurfaceGui,
	storeName: string,
	_registryConn: Signal.SignalConnection?,
}, LeaderboardScreen))

local function resolveBoardId(instance: Instance): string
	local attr = instance:GetAttribute("OrderedStoreName")
	if typeof(attr) == "string" and attr ~= "" then
		return BOARD_ID_ALIASES[attr] or attr
	end
	return BOARD_ID_ALIASES[instance.Name] or instance.Name
end

-- 为 Workspace.World.LeaderBoard 下已放置的模型自动打标签并补全 OrderedStoreName
function LeaderboardScreen.bootstrapWorkspace()
	local world = Workspace:FindFirstChild("World")
	local folder = world and world:FindFirstChild("LeaderBoard")
	if not folder then
		return
	end

	for _, child in ipairs(folder:GetChildren()) do
		if not CollectionService:HasTag(child, TagCategory.LeaderboardScreen) then
			CollectionService:AddTag(child, TagCategory.LeaderboardScreen)
		end
		local attr = child:GetAttribute("OrderedStoreName")
		if typeof(attr) ~= "string" or attr == "" then
			local boardId = BOARD_ID_ALIASES[child.Name]
			if boardId then
				child:SetAttribute("OrderedStoreName", boardId)
			end
		end
	end
end

local GUI_PREFABS = ReplicatedStorage:WaitForChild("Instances")
	:WaitForChild("Prefabs")
	:WaitForChild("Gui")

local function getSurfaceGuiPrefab(): SurfaceGui
	return GUI_PREFABS:WaitForChild("LeaderboardSurfaceGui") :: SurfaceGui
end

local function resolveAdornee(instance: Instance): BasePart
	if instance:IsA("BasePart") then
		return instance
	end

	local screen = instance:FindFirstChild("Screen", true)
	if screen and screen:IsA("BasePart") then
		return screen
	end

	if instance:IsA("Model") and instance.PrimaryPart then
		return instance.PrimaryPart
	end

	error(string.format("[LeaderboardScreen] cannot resolve adornee for %s", instance:GetFullName()))
end

function LeaderboardScreen.new(instance: Instance): ClassType
	local self = {
		_instance = instance,
		_registryConn = nil,
	}
	setmetatable(self, LeaderboardScreen)

	self.storeName = resolveBoardId(instance)
	self.surfaceGui = getSurfaceGuiPrefab():Clone()
	self.leadboard = LeaderboardDisplay.new(self.storeName)

	if not LeaderboardConfig.getBoard(self.storeName) then
		warn("[LeaderboardScreen] 未配置的 OrderedStoreName: ", self.storeName, instance:GetFullName())
	end

	self:setup()
	self:listen()

	return self
end

function LeaderboardScreen.setup(self: ClassType)
	local adornee = resolveAdornee(self._instance)
	self.surfaceGui.Parent = adornee
	self.surfaceGui.Adornee = adornee
	self.leadboard:setParent(self.surfaceGui)
	self.leadboard:setVisible(true)
end

function LeaderboardScreen.refreshFromCache(self: ClassType)
	local cached = LeaderboardScreenRegistry.getCached(self.storeName)
	if cached then
		self.leadboard:refreshLeaderboardAsync(cached.entries)
	end
end

function LeaderboardScreen.listen(self: ClassType)
	self:refreshFromCache()

	self._registryConn = LeaderboardScreenRegistry.onUpdated(function(boardId, entries)
		if boardId == self.storeName then
			self.leadboard:refreshLeaderboardAsync(entries)
		end
	end)
end

function LeaderboardScreen.destroy(self: ClassType)
	if self._registryConn then
		self._registryConn:Disconnect()
		self._registryConn = nil
	end
	self.surfaceGui:Destroy()
	self.leadboard:destroy()
end

return LeaderboardScreen
