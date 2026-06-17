--!strict

--[[
	兑换码输入面板。
	StarterGui 预制体：GUI_Codes（结构移植自 spicy CodesGui）
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = ReplicatedStorage.ReplicatedCode.Framework
local GameLogic = ReplicatedStorage.ReplicatedCode.GameLogic

local GuiBase = require(Framework.UI.GuiBase)
local UILayerId = require(Framework.UI.UILayerId)
local UILayerType = require(Framework.UI.UILayerType)
local UILayerHandler = require(Framework.UI.UILayerHandler)
local Network = require(Framework.Core.Network)
local NetSignals = require(Framework.Core.Network.NetSignals)
local TriggerSignalCategory = require(GameLogic.SharedConstants.Categories.TriggerSignalCategory)
local NotifyCategory = require(GameLogic.SharedConstants.Categories.NotifyCategory)
local RemoteFunctionKey = require(GameLogic.SharedConstants.Keys.RemoteFunctionKey)

local CodesGui = GuiBase.new(UILayerId.GUI_Codes, UILayerType.Menu)

local textBox: TextBox? = nil
local redeemBtn: GuiButton? = nil
local redeeming = false

local function notify(message: string, category: string)
	NetSignals.getSignal(TriggerSignalCategory.Client.notify):Fire(message, category)
end

local function findRoot(gui: ScreenGui): Instance
	return gui:FindFirstChild("Main") or gui:FindFirstChild("Frame") or gui
end

local function ensureTextBox(container: Frame): TextBox
	local existing = container:FindFirstChildWhichIsA("TextBox")
	if existing and existing:IsA("TextBox") then
		return existing
	end

	local input = Instance.new("TextBox")
	input.Name = "Input"
	input.BackgroundTransparency = 1
	input.BorderSizePixel = 0
	input.ClearTextOnFocus = false
	input.Font = Enum.Font.GothamMedium
	input.PlaceholderText = "Type here..."
	input.PlaceholderColor3 = Color3.fromRGB(180, 180, 180)
	input.Text = ""
	input.TextColor3 = Color3.fromRGB(255, 255, 255)
	input.TextSize = 18
	input.TextXAlignment = Enum.TextXAlignment.Left
	input.Size = UDim2.fromScale(1, 1)
	input.Position = UDim2.fromScale(0, 0)
	input.ZIndex = 2
	input.Parent = container

	local placeholder = container:FindFirstChild("Type here...") :: TextLabel?
	if placeholder then
		placeholder.Visible = false
	end

	return input
end

local function onRedeem()
	if redeeming or not textBox then
		return
	end

	local code = string.gsub(textBox.Text, "^%s*(.-)%s*$", "%1")
	if code == "" then
		return
	end

	redeeming = true
	task.spawn(function()
		local pcallOk, success, message = Network.invokeServerAsync(RemoteFunctionKey.Code_Redeem, code)
		redeeming = false

		if not pcallOk then
			notify("Redeem failed, please try again later!", NotifyCategory.Error)
			return
		end

		if success then
			textBox.Text = ""
		else
			notify(tostring(message), NotifyCategory.Error)
		end
	end)
end

function CodesGui:start()
	local gui = self:bindScreenGui()
	local root = findRoot(gui) :: Frame

	local header = root:FindFirstChild("Header") or root:FindFirstChild("Top")
	local content = root:WaitForChild("Content") :: Frame
	local menu = root:FindFirstChild("Menu")

	local textBoxContainer = content:WaitForChild("TextBox") :: Frame
	textBox = ensureTextBox(textBoxContainer)
	redeemBtn = content:WaitForChild("RedeemButton") :: GuiButton

	local exitBtn = if header then header:FindFirstChild("ExitButton") or header:FindFirstChild("CloseButton") else nil
	if exitBtn and exitBtn:IsA("GuiButton") then
		exitBtn.Activated:Connect(function()
			UILayerHandler.hide(self.Name)
		end)
	end

	if menu then
		local likeCodesMenu = menu:FindFirstChild("LikeCodes") :: Frame?
		local likeCodesBtn = likeCodesMenu and likeCodesMenu:FindFirstChild("Button")
		if likeCodesBtn and likeCodesBtn:IsA("GuiButton") then
			likeCodesBtn.Activated:Connect(function()
				UILayerHandler.show(UILayerId.GUI_LikesCodes)
			end)
		end
	end
end

function CodesGui:listen()
	local button = redeemBtn
	if button then
		button.Activated:Connect(function()
			if button.Active then
				onRedeem()
			end
		end)
	end
end

return CodesGui
