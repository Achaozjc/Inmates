--!strict

--[[
	Machine_Upgrader 立即完成按钮（纯客户端）。

	点击自己基地 Builds/Machine_Upgrader/CompleteButon/SurfaceGui/Frame/CompleteButon
	时，向服务端发起 InstantProcess 开发者商品购买（Robux 付款弹窗）。
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Framework = ReplicatedStorage.ReplicatedCode.Framework
local GameLogic = ReplicatedStorage.ReplicatedCode.GameLogic

local Network = require(Framework.Core.Network)
local BaseConfig = require(GameLogic.Shared.Configs.BaseConfig)
local AttributeEnum = require(GameLogic.Shared.Enums.AttributeEnum)
local CurrencyTypes = require(GameLogic.SharedConstants.Types.CurrencyTypes)
local RemoteEventKey = require(GameLogic.SharedConstants.Keys.RemoteEventKey)
local StoreIdCategory = require(GameLogic.SharedConstants.Categories.StoreIdCategory)

local MACHINE_UPGRADER_NAME = "Machine_Upgrader"
local COMPLETE_PART_NAME = "CompleteButon"
local COMPLETE_BUTTON_NAME = "CompleteButon"

local localPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() :: Player

local MachineUpgraderCompleteController = {
	Name = "MachineUpgraderCompleteController",
	_started = false,
}

local lastClickAt = 0

local function findBaseByOwner(userId: number): Folder?
	local world = Workspace:FindFirstChild("World")
	if not world then
		return nil
	end
	for _, child in world:GetChildren() do
		if child:IsA("Folder") and string.match(child.Name, "^Base_%d+$") then
			if child:GetAttribute(AttributeEnum.OwnerId) == userId then
				return child
			end
		end
	end
	return nil
end

local function waitForMyBase(): Folder
	local base = findBaseByOwner(localPlayer.UserId)
	while not base do
		task.wait(0.1)
		base = findBaseByOwner(localPlayer.UserId)
	end
	return base
end

-- 带超时的 WaitForChild 链式查找：基地复制后 Builds 子树可能尚未到达客户端
local function waitForDescendant(root: Instance, names: { string }, timeout: number): Instance?
	local current: Instance? = root
	for _, name in names do
		if not current then
			return nil
		end
		current = current:WaitForChild(name, timeout)
	end
	return current
end

local COMPLETE_BUTTON_PATH = {
	"Touch_Collection",
	MACHINE_UPGRADER_NAME,
	COMPLETE_PART_NAME,
	"SurfaceGui",
	"Frame",
	COMPLETE_BUTTON_NAME,
}

local function onCompleteActivated()
	local productId = StoreIdCategory.Product.InstantProcess
	if not productId or productId <= 0 then
		warn("[MachineUpgraderCompleteController] InstantProcess product id is not configured")
		return
	end

	local now = os.clock()
	if now - lastClickAt < BaseConfig.BUTTON_DEBOUNCE then
		return
	end
	lastClickAt = now

	Network.fireServer(RemoteEventKey.PurchasePending, CurrencyTypes.PriceType.Product, productId)
end

function MachineUpgraderCompleteController:init()
	if self._started then
		return
	end
	self._started = true

	task.spawn(function()
		local base = waitForMyBase()
		local button = waitForDescendant(base, COMPLETE_BUTTON_PATH, 30)
		if not button or not button:IsA("TextButton") then
			warn(
				"[MachineUpgraderCompleteController] 未找到 Touch_Collection/Machine_Upgrader/CompleteButon/SurfaceGui/Frame/CompleteButon"
			)
			return
		end

		button.Activated:Connect(onCompleteActivated)
	end)
end

return MachineUpgraderCompleteController
