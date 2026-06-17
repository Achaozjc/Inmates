--!strict

--[[
	Experience Event 面板（移植自 dingdong EventGui，UI：StarterGui.Gui_Event）。
	Frame.Main：Event / Update 列表 + 右侧 Info / Rewards；Top.ExitButton 关闭。
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = ReplicatedStorage.ReplicatedCode.Framework
local GameLogic = ReplicatedStorage.ReplicatedCode.GameLogic

local GuiBase = require(Framework.UI.GuiBase)
local UILayerId = require(Framework.UI.UILayerId)
local UILayerType = require(Framework.UI.UILayerType)
local UILayerHandler = require(Framework.UI.UILayerHandler)
local ShowUnitNum = require(Framework.UI.ShowUnitNum)
local Network = require(Framework.Core.Network)
local NetSignals = require(Framework.Core.Network.NetSignals)
local PlayerDataClient = require(Framework.DataStore.PlayerDataClient)
local EventConfig = require(GameLogic.Shared.Configs.EventConfig)
local SocialManager = require(GameLogic.Managers.SocialManager)
local PlayerDataKey = require(GameLogic.SharedConstants.Keys.PlayerDataKey)
local RemoteFunctionKey = require(GameLogic.SharedConstants.Keys.RemoteFunctionKey)
local TriggerSignalCategory = require(GameLogic.SharedConstants.Categories.TriggerSignalCategory)
local NotifyCategory = require(GameLogic.SharedConstants.Categories.NotifyCategory)

local EventGui = GuiBase.new(UILayerId.Gui_Event, UILayerType.Menu)

type EventEntry = EventConfig.EventEntry

local eventScroll: ScrollingFrame? = nil
local updateScroll: ScrollingFrame? = nil
local template: GuiButton? = nil
local infoTitle: TextLabel? = nil
local infoDes: TextLabel? = nil
local rewardsFrame: Frame? = nil
local verifyButton: GuiButton? = nil
local verifyLabel: TextLabel? = nil
local rewardsList: Frame? = nil
local cashRewardLabel: TextLabel? = nil

local temps: { [string]: GuiButton } = {}
local selectButton: GuiButton? = nil
local verifyConnection: RBXScriptConnection? = nil
local defaultSelectKey: string? = nil

local function notify(success: boolean, message: string?)
	if success then
		local text = if type(message) == "string" and message ~= "" then message else "Success!"
		NetSignals.getSignal(TriggerSignalCategory.Client.notify):Fire(text, NotifyCategory.Success)
	else
		local text = if type(message) == "string" and message ~= "" then message else "Error!"
		NetSignals.getSignal(TriggerSignalCategory.Client.notify):Fire(text, NotifyCategory.Error)
	end
end

local function getOwnedAxeCount(): number
	local axeTycoon = PlayerDataClient.get(PlayerDataKey.AxeTycoon)
	if type(axeTycoon) ~= "table" then
		return 0
	end
	return tonumber(axeTycoon.ownedAxeCount) or 0
end

-- 刷新 RewardsList.Cash 预制体标签：默认隐藏，选中可预约活动且 Rewards 区可见时展示
local function refreshCashRewardLabel(shouldShow: boolean?)
	local label = cashRewardLabel
	if not label then
		return
	end

	local show = if shouldShow ~= nil
		then shouldShow
		else (rewardsFrame ~= nil and rewardsFrame.Visible)

	if not show then
		label.Visible = false
		return
	end

	label.Text = string.format("+$%s", ShowUnitNum(EventConfig.getReward(getOwnedAxeCount())))
	label.Visible = true
end

local function updateVerifyButton(followed: boolean)
	local label = verifyLabel
	local button = verifyButton
	if not label or not button then
		return
	end

	if followed then
		label.Text = "Followed"
		button.BackgroundTransparency = 1
	else
		label.Text = "Notify Me"
		button.BackgroundTransparency = 0
	end
end

local function fireServerClaimed(key: string, temp: GuiButton, eventId: string)
	local invokeOk, success, message = Network.invokeServerAsync(RemoteFunctionKey.GetEventRewards, eventId)
	if not invokeOk then
		notify(false, "Request failed")
		return
	end

	notify(success == true, if typeof(message) == "string" then message else nil)
	if success then
		temp:SetAttribute("followed", true)
		temp.Owned.Visible = false
		updateVerifyButton(true)
	end
end

local function updateIndexInfo(key: string, temp: GuiButton, info: EventEntry, done: boolean?)
	if verifyConnection then
		verifyConnection:Disconnect()
		verifyConnection = nil
	end

	local title = infoTitle
	local des = infoDes
	local rewards = rewardsFrame
	if not title or not des or not rewards then
		return
	end

	title.Text = info.name
	des.Text = info.des or ""

	local isDone = done == true
	rewards.Visible = not isDone
	refreshCashRewardLabel(not isDone)

	if isDone then
		return
	end

	local eventReward = PlayerDataClient.get(PlayerDataKey.EventReward)
	local followed = temp:GetAttribute("followed") == true
	local claimed = type(eventReward) == "table" and eventReward[info.eventId] == true

	updateVerifyButton(claimed or followed)

	local button = verifyButton
	if not button then
		return
	end

	verifyConnection = button.Activated:Connect(function()
		if not followed then
			local rsvpStatus = SocialManager.followEvent(info.eventId)
			local result = SocialManager.checkRsvpStatus(rsvpStatus)
			temp:SetAttribute("followed", result)
			followed = result
			if result then
				fireServerClaimed(key, temp, info.eventId)
			end
		elseif not claimed then
			fireServerClaimed(key, temp, info.eventId)
		end
	end)
end

local function selectEvent(key: string, button: GuiButton, info: EventEntry, done: boolean?)
	if selectButton then
		local stroke = selectButton:FindFirstChild("UIStroke") :: UIStroke?
		if stroke then
			stroke.Enabled = false
		end
	end

	selectButton = button
	local stroke = button:FindFirstChild("UIStroke") :: UIStroke?
	if stroke then
		stroke.Enabled = true
	end

	updateIndexInfo(key, button, info, done)
end

local function updateTemps(eventData: any?)
	local data = eventData or PlayerDataClient.get(PlayerDataKey.EventReward)

	for key, temp in temps do
		local info = EventConfig.events[key]
		if not info then
			continue
		end

		local claimed = type(data) == "table" and data[info.eventId] == true
		local done = info.done
		temp.Owned.Visible = not claimed and not done

		NetSignals.getSignal(TriggerSignalCategory.Client.redPoint):Fire(
			EventGui.Name,
			key,
			not done and not claimed
		)
	end
end

local function createTemps()
	local eventParent = eventScroll
	local updateParent = updateScroll
	local tempTemplate = template
	if not eventParent or not updateParent or not tempTemplate then
		return
	end

	for key, info in EventConfig.events do
		local temp = tempTemplate:Clone() :: GuiButton
		temp.Name = "Event_" .. key
		temp.Visible = true
		local label = temp:FindFirstChild("Label") :: TextLabel?
		if label then
			label.Text = info.name
		end

		if info.done then
			temp.Parent = updateParent
			temp.LayoutOrder = -tonumber(key)
		else
			temp.Parent = eventParent
			temp.LayoutOrder = tonumber(key) or 0
			if not defaultSelectKey then
				defaultSelectKey = key
			end
		end

		temp.Activated:Connect(function()
			selectEvent(key, temp, info, info.done)
		end)

		local rsvpStatus = SocialManager.getEventRsvpStatus(info.eventId, "EventGui")
		temp:SetAttribute("followed", SocialManager.checkRsvpStatus(rsvpStatus))

		temps[key] = temp
	end

	tempTemplate.Visible = false

	if defaultSelectKey then
		local info = EventConfig.events[defaultSelectKey]
		local temp = temps[defaultSelectKey]
		if info and temp then
			selectEvent(defaultSelectKey, temp, info, info.done)
		end
	end
end

function EventGui:start()
	local gui = self:bindScreenGui()
	local frame = gui:WaitForChild("Frame") :: Frame
	local main = frame:WaitForChild("Main") :: Frame
	local top = frame:WaitForChild("Top") :: Frame
	local right = main:WaitForChild("Right") :: Frame

	eventScroll = main:WaitForChild("Event") :: ScrollingFrame
	updateScroll = main:WaitForChild("Update") :: ScrollingFrame
	template = main:WaitForChild("Template") :: GuiButton

	local info = right:WaitForChild("Info") :: ScrollingFrame
	infoTitle = info:WaitForChild("Title") :: TextLabel
	infoDes = info:WaitForChild("Des") :: TextLabel

	rewardsFrame = right:WaitForChild("Rewards") :: Frame
	local rewardsInner = rewardsFrame:WaitForChild("Frame") :: Frame
	rewardsList = rewardsInner:WaitForChild("RewardsList") :: Frame
	cashRewardLabel = rewardsList:WaitForChild("Cash") :: TextLabel
	cashRewardLabel.Visible = false
	verifyButton = rewardsInner:WaitForChild("VerifyButton") :: GuiButton
	verifyLabel = verifyButton:WaitForChild("Label") :: TextLabel

	local exitBtn = top:WaitForChild("ExitButton") :: GuiButton
	exitBtn.Activated:Connect(function()
		UILayerHandler.hide(self.Name)
	end)

	createTemps()
end

function EventGui:listen()
	PlayerDataClient.getUpdateSignal(PlayerDataKey.EventReward):Connect(function(value)
		updateTemps(value)
	end)

	task.delay(1, function()
		updateTemps(PlayerDataClient.get(PlayerDataKey.EventReward))
	end)

	PlayerDataClient.getUpdateSignal(PlayerDataKey.AxeTycoon):Connect(function()
		refreshCashRewardLabel(nil)
	end)

	if self.switchSignal then
		self.switchSignal.Event:Connect(function(isVisible: boolean)
			if isVisible then
				refreshCashRewardLabel(nil)
				updateTemps(PlayerDataClient.get(PlayerDataKey.EventReward))
			end
		end)
	end
end

return EventGui
