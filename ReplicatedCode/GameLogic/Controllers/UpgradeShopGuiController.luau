--!strict

--[[
	永久升级商店屏幕控制器（纯客户端显示）。

	职责：
	1. 玩家被分配到基地后，把预制体 ReplicatedStorage/Instances/Prefabs/Gui/UpgradeShopGui
	   克隆到本地 PlayerGui，并把 Adornee 指向自己基地的 Shop/Screen 部件。
	2. 按 GamepassConfig.Passes 刷新每个按钮的价格行：
	   未拥有 → 显示 "xxx R$"（价格经 MarketplaceService:GetProductInfo 拉取）；
	   已拥有 → 显示 "Owned" 并隐藏货币图标（拥有状态读玩家属性，由服务端 GamepassService 写入）。
	3. 点击未拥有的通行证按钮时弹出 Roblox 官方购买页（PromptGamePassPurchase），
	   购买成功由服务端 GamepassService 监听 PromptGamePassPurchaseFinished 后授予。

	预制体按钮命名与 GamepassConfig.Passes 的 key 一致（AutoCollectCash / AutoCollectWood / DoubleWood），
	每个按钮内含 PriceFrame/CoinIcon + PriceFrame/PriceLabel。

	说明：SurfaceGui 放在 PlayerGui 并设置 Adornee 后仅本地玩家可见，
	这样每个玩家只会在自己基地的屏幕上看到属于自己的商店界面。
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameLogic = ReplicatedStorage.ReplicatedCode.GameLogic

local AttributeEnum = require(GameLogic.Shared.Enums.AttributeEnum)
local GamepassConfig = require(GameLogic.Shared.Configs.GamepassConfig)
local StoreIdCategory = require(GameLogic.SharedConstants.Categories.StoreIdCategory)

local localPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() :: Player

local PREFAB_NAME = "UpgradeShopGui"

local UpgradeShopGuiController = {
	Name = "UpgradeShopGuiController",
	_started = false,
	_gui = nil :: SurfaceGui?,
}

-- 扫描 Workspace.World 下所有 Base_*，返回 OwnerId 属性匹配指定 UserId 的基地
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

-- 阻塞等待，直到本地玩家被分配到基地（服务端写好 OwnerId 后即可命中）
local function waitForMyBase(): Folder
	local base = findBaseByOwner(localPlayer.UserId)
	while not base do
		task.wait(0.1)
		base = findBaseByOwner(localPlayer.UserId)
	end
	return base
end

-- 带超时的 WaitForChild 链式查找：刚进服时实例可能尚未复制完成，需等待而非一次性查找
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

-- 解析商店屏幕 SurfaceGui 预制体（ReplicatedStorage.Instances.Prefabs.Gui.UpgradeShopGui）
local function resolvePrefab(): SurfaceGui?
	local prefab = waitForDescendant(ReplicatedStorage, { "Instances", "Prefabs", "Gui", PREFAB_NAME }, 10)
	return if prefab and prefab:IsA("SurfaceGui") then prefab else nil
end

-- 拉取通行证 Robux 价格；失败返回 nil（保留占位文本）
local function fetchPrice(gamepassId: number): number?
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(gamepassId, Enum.InfoType.GamePass)
	end)
	return if ok and type(info) == "table" then tonumber(info.PriceInRobux) else nil
end

-- 刷新单个按钮的价格行：已拥有 → "Owned" 且隐藏图标；未拥有 → "xxx R$"
local function refreshPriceRow(button: Instance, attribute: string, priceText: string?)
	local priceFrame = button:FindFirstChild("PriceFrame")
	local priceLabel = priceFrame and priceFrame:FindFirstChild("PriceLabel")
	local coinIcon = priceFrame and priceFrame:FindFirstChild("CoinIcon")
	if not (priceLabel and priceLabel:IsA("TextLabel")) then
		return
	end

	local owned = localPlayer:GetAttribute(attribute) == true
	if owned then
		priceLabel.Text = "Owned"
	elseif priceText then
		priceLabel.Text = priceText
	end
	if coinIcon and coinIcon:IsA("GuiObject") then
		coinIcon.Visible = not owned
	end
end

-- 装配价格与拥有状态：拉价、刷新显示，并监听拥有属性变化（购买成功后即时变 Owned）
local function setupPassButtons(gui: SurfaceGui)
	local panel = gui:FindFirstChild("Panel")
	local list = panel and panel:FindFirstChild("ButtonList")
	if not list then
		warn("[UpgradeShopGuiController] 预制体缺少 Panel/ButtonList")
		return
	end

	for _, pass in ipairs(GamepassConfig.Passes) do
		local button = list:FindFirstChild(pass.key)
		if not button then
			warn("[UpgradeShopGuiController] 预制体缺少按钮：" .. pass.key)
			continue
		end

		-- 先按当前拥有状态刷新一次（价格未拉到前保留预制体占位文本）
		refreshPriceRow(button, pass.attribute, nil)

		-- 拥有属性变化（购买成功/重连同步）时刷新
		localPlayer:GetAttributeChangedSignal(pass.attribute):Connect(function()
			refreshPriceRow(button, pass.attribute, nil)
		end)

		-- 异步拉取 Robux 价格后填入 "xxx R$"
		local gamepassId = StoreIdCategory.Gamepass[pass.key]
		if gamepassId and gamepassId > 0 then
			task.spawn(function()
				local price = fetchPrice(gamepassId)
				if price then
					refreshPriceRow(button, pass.attribute, price .. " R$")
				end
			end)
		end

		-- 点击未拥有的通行证时弹出 Roblox 官方购买页（购买结果由服务端 GamepassService 监听处理）
		if button:IsA("GuiButton") and gamepassId and gamepassId > 0 then
			button.Activated:Connect(function()
				if localPlayer:GetAttribute(pass.attribute) == true then
					return
				end
				MarketplaceService:PromptGamePassPurchase(localPlayer, gamepassId)
			end)
		end
	end
end

function UpgradeShopGuiController:init()
	if self._started then
		return
	end
	self._started = true

	task.spawn(function()
		local base = waitForMyBase()

		-- OwnerId 属性可能先于基地子对象复制到客户端，需用 WaitForChild 等待
		local screen = waitForDescendant(base, { "Shop", "Screen" }, 10)
		if not (screen and screen:IsA("BasePart")) then
			warn("[UpgradeShopGuiController] 未找到基地 Shop/Screen 部件：" .. base.Name)
			return
		end

		local prefab = resolvePrefab()
		if not prefab then
			warn("[UpgradeShopGuiController] 未找到预制体 ReplicatedStorage/Instances/Prefabs/Gui/" .. PREFAB_NAME)
			return
		end

		local gui = prefab:Clone()
		gui.Adornee = screen
		gui.Parent = localPlayer:WaitForChild("PlayerGui")
		self._gui = gui

		setupPassButtons(gui)
	end)
end

return UpgradeShopGuiController
