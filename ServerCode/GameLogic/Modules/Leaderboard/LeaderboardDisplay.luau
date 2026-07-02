--!strict
-- 世界排行榜 SurfaceGui 行渲染（移植自 dingdong LeaderboardScreen/Leaderboard.luau）

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OrderedStoreNames = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.OrderedStoreNames)
local LeaderboardConfig = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Configs.LeaderboardConfig)
local LeaderboardScore = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Leaderboard.LeaderboardScore)
local DecimalStringToOrderedScore = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Leaderboard.DecimalStringToOrderedScore)
local showUnitNum = require(ReplicatedStorage.ReplicatedCode.Framework.UI.ShowUnitNum)

local DISPLAY_COUNT = 100
local USER_ICON_TEMPLATE = "rbxthumb://type=AvatarHeadShot&id=%d&w=60&h=60"

local RankColor = {
	[1] = Color3.fromRGB(95, 208, 69),
	[2] = Color3.fromRGB(137, 207, 213),
	[3] = Color3.fromRGB(183, 129, 194),
}

local LeaderboardDisplay = {}
LeaderboardDisplay.__index = LeaderboardDisplay

export type ClassType = typeof(setmetatable(
	{} :: {
		userIdUsernameCache: { [number]: string },
		displayFrames: { Frame },
		storeName: OrderedStoreNames.EnumType,
		board: Frame,
		list: ScrollingFrame,
	},
	LeaderboardDisplay
))

local GUI_PREFABS = ReplicatedStorage:WaitForChild("Instances")
	:WaitForChild("Prefabs")
	:WaitForChild("Gui")

local function getLeaderboardPrefab(name: string): Instance
	local prefab = GUI_PREFABS:FindFirstChild(name)
	if prefab then
		return prefab
	end
	error(string.format("[LeaderboardDisplay] missing prefab: Instances.Prefabs.Gui.%s", name))
end

function LeaderboardDisplay.new(storeName: OrderedStoreNames.EnumType): ClassType
	local self = setmetatable({}, LeaderboardDisplay)

	self.userIdUsernameCache = {}
	self.displayFrames = {}
	self.storeName = storeName

	local boardListTemplate = getLeaderboardPrefab("BoardListTemplate") :: Frame
	self.board = boardListTemplate:Clone()
	self.list = self.board:FindFirstChild("List") :: ScrollingFrame
	self.board.Name = storeName

	local title = self.board.TitleBox.Label
	local boardConfig = LeaderboardConfig.getBoard(storeName)
	title.Text = if boardConfig and boardConfig.name then boardConfig.name else tostring(storeName)

	self:createDisplayFrames()

	return self
end

function LeaderboardDisplay.setParent(self: ClassType, parent: Instance)
	self.board.Parent = parent
end

function LeaderboardDisplay.setVisible(self: ClassType, visible: boolean)
	self.board.Visible = visible
end

function LeaderboardDisplay.handleValue(self: ClassType, value: number | string)
	local cfg = LeaderboardConfig.getBoard(self.storeName)
	if cfg then
		return LeaderboardScore.formatDisplayValue(value, cfg.metricKind)
	end
	if typeof(value) == "string" then
		return showUnitNum(tonumber(value) or 0)
	end
	return showUnitNum(DecimalStringToOrderedScore.decodeOrderedScore(value))
end

function LeaderboardDisplay.updateDisplayFrameInfo(
	self: ClassType,
	displayFrame: Frame,
	playerName: string?,
	userId: number?,
	value: string?
)
	if playerName and userId and value then
		local displayIcon = string.format(USER_ICON_TEMPLATE, userId)
		displayFrame.NameLabel.Text = playerName
		displayFrame.Icon.Image = displayIcon
		displayFrame.Value.Text = value
		displayFrame.Visible = true
	else
		displayFrame.Visible = false
	end
end

function LeaderboardDisplay.getUsernameFromUserIdAsync(self: ClassType, userId: number): string
	if self.userIdUsernameCache[userId] then
		return self.userIdUsernameCache[userId]
	end

	local success, result = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	if success then
		self.userIdUsernameCache[userId] = result
		return result
	end
	return string.format("<unknown%d>", userId)
end

function LeaderboardDisplay.refreshLeaderboardAsync(self: ClassType, topPlayerDatas: { { key: string, value: number } })
	if not next(topPlayerDatas) then
		return
	end

	for rank = 1, DISPLAY_COUNT do
		local data = topPlayerDatas[rank]
		local displayFrame = self.displayFrames[rank]

		if data and displayFrame then
			local playerName, userIdStr = data.key:match("(.+)_(.+)")
			local dv = data.value
			local dataValue: number | string = if typeof(dv) == "number" or typeof(dv) == "string" then dv else (tonumber(dv) or 0)
			local value = self:handleValue(dataValue)
			self:updateDisplayFrameInfo(displayFrame, playerName, tonumber(userIdStr), value)
		elseif displayFrame then
			self:updateDisplayFrameInfo(displayFrame, nil, nil, nil)
		end
	end
end

function LeaderboardDisplay.createDisplayFrames(self: ClassType)
	local leaderBoardTemplate = getLeaderboardPrefab("LeaderBoardTemplate") :: Frame

	for i = 1, DISPLAY_COUNT do
		local displayFrame = leaderBoardTemplate:Clone()
		displayFrame.LayoutOrder = i
		displayFrame.RankLabel.Text = "#" .. tostring(i)
		displayFrame.Visible = false
		displayFrame.Parent = self.list
		displayFrame.Name = string.format("rank_%d", i)

		if RankColor[i] then
			displayFrame.RankLabel.TextColor3 = RankColor[i]
			displayFrame.NameLabel.TextColor3 = RankColor[i]
			displayFrame.Value.TextColor3 = RankColor[i]
		end

		self.displayFrames[i] = displayFrame
	end
end

function LeaderboardDisplay.destroy(self: ClassType)
	self.board:Destroy()
end

return LeaderboardDisplay
