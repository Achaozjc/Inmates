--!strict

--[[
	点赞解锁兑换码展示面板。
	StarterGui 预制体：GUI_LikesCodes（结构移植自 spicy LikesCodesGui）
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = ReplicatedStorage.ReplicatedCode.Framework
local GameLogic = ReplicatedStorage.ReplicatedCode.GameLogic

local GuiBase = require(Framework.UI.GuiBase)
local UILayerId = require(Framework.UI.UILayerId)
local UILayerType = require(Framework.UI.UILayerType)
local UILayerHandler = require(Framework.UI.UILayerHandler)
local ShowUnitNum = require(Framework.UI.ShowUnitNum)
local CodeController = require(GameLogic.Controllers.CodeController)
local CodeRewardConfig = require(GameLogic.Shared.Configs.CodeRewardConfig)

local LikesCodesGui = GuiBase.new(UILayerId.GUI_LikesCodes, UILayerType.Menu)

local RELEASED_GRADIENT = ColorSequence.new(Color3.fromRGB(85, 255, 127))
local LOCKED_GRADIENT = ColorSequence.new(Color3.new(1, 1, 1))

type CodeRow = {
	code: string,
	voteTarget: number,
	row: Frame,
}

local listFrame: Frame? = nil
local template: Frame? = nil
local rows: { CodeRow } = {}
local changedConn: RBXScriptConnection? = nil

local function getSortedCodeEntries(): { { code: string, voteTarget: number } }
	local entries: { { code: string, voteTarget: number } } = {}
	for code, info in pairs(CodeRewardConfig.Codes) do
		local voteTarget = tonumber(info.voteTarget)
		if voteTarget and voteTarget > 0 then
			table.insert(entries, {
				code = string.lower(code),
				voteTarget = voteTarget,
			})
		end
	end
	table.sort(entries, function(a, b)
		return a.voteTarget < b.voteTarget
	end)
	return entries
end

local function buildCodeList()
	if not listFrame or not template then
		return
	end

	for _, child in ipairs(listFrame:GetChildren()) do
		if child:IsA("GuiObject") and child ~= template then
			child:Destroy()
		end
	end
	rows = {}

	local layout = listFrame:FindFirstChildOfClass("UIListLayout")
	if not layout then
		layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 8)
		layout.Parent = listFrame
	end

	for index, entry in ipairs(getSortedCodeEntries()) do
		local row = template:Clone()
		row.Name = "CodeRow_" .. index
		row.LayoutOrder = index
		row.Visible = true

		local codeLabel = row:FindFirstChild("CodeLabel") :: TextLabel?
		if codeLabel then
			codeLabel.Text = "loading..."
		end

		row.Parent = listFrame
		table.insert(rows, {
			code = entry.code,
			voteTarget = entry.voteTarget,
			row = row,
		})
	end
end

local function refreshRows()
	local likes = CodeController.getLikes()
	local releasedSet: { [string]: boolean } = {}
	for _, code in ipairs(CodeController.getReleasedList()) do
		releasedSet[code] = true
	end

	for _, item in ipairs(rows) do
		if not item.row.Parent then
			continue
		end

		local codeLabel = item.row:FindFirstChild("CodeLabel") :: TextLabel?
		local bar = item.row:FindFirstChild("Bar") :: Frame?
		if not codeLabel or not bar then
			continue
		end

		local gradient = codeLabel:FindFirstChild("UIGradient") :: UIGradient?
		if releasedSet[item.code] then
			codeLabel.Text = item.code
			if gradient then
				gradient.Color = RELEASED_GRADIENT
			end
			bar.Size = UDim2.fromScale(1, 1)
		elseif likes >= item.voteTarget then
			item.row:Destroy()
		else
			codeLabel.Text = string.format("%s likes", ShowUnitNum(item.voteTarget))
			if gradient then
				gradient.Color = LOCKED_GRADIENT
			end
			bar.Size = UDim2.fromScale(math.clamp(likes / item.voteTarget, 0, 1), 1)
		end
	end
end

function LikesCodesGui:start()
	local gui = self:bindScreenGui()

	local likeCodes = gui:WaitForChild("LikeCodes") :: Frame
	local header = likeCodes:WaitForChild("Header") :: Frame
	listFrame = likeCodes:WaitForChild("Frame") :: Frame
	template = listFrame:WaitForChild("Template") :: Frame
	template.Visible = false

	local closeBtn = header:WaitForChild("Close") :: GuiButton
	closeBtn.Activated:Connect(function()
		UILayerHandler.hide(self.Name)
	end)

	buildCodeList()

	if self.switchSignal then
		self.switchSignal.Event:Connect(function(isVisible: boolean)
			if not isVisible then
				if changedConn then
					changedConn:Disconnect()
					changedConn = nil
				end
				return
			end

			CodeController.requestStateAsync()
			refreshRows()
			if changedConn then
				changedConn:Disconnect()
			end
			changedConn = CodeController.changed:Connect(refreshRows)
		end)
	end
end

function LikesCodesGui:listen() end

return LikesCodesGui
