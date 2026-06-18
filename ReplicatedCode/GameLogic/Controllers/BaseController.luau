--!strict

--[[
	客户端基地绑定控制器（参考 dingdong 项目 BaseManagerClient 模式）。

	职责：
	- 按服务端写在 Base_* 折叠上的 OwnerId 属性，定位本地玩家自己的基地
	- 角色每次重生后自动归位到自己基地的出生点
	- 提供「一键返回基地」快捷键，方便玩家随时回家

	说明：本地玩家对自己角色拥有网络所有权，客户端设置 HumanoidRootPart 的 CFrame
	会复制到服务端，因此归位逻辑全部在客户端完成，无需新增 Remote。
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local Workspace = game:GetService("Workspace")

local GameLogic = ReplicatedStorage.ReplicatedCode.GameLogic

local LocalCharacter = require(GameLogic.Modules.LocalCharacter)
local AttributeEnum = require(GameLogic.Shared.Enums.AttributeEnum)
local AfkTeleport = require(GameLogic.Shared.Misc.AfkTeleport)
local BaseStackingAnchor = require(GameLogic.Shared.Misc.BaseStackingAnchor)

local localPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() :: Player

-- 返回基地快捷键绑定名与按键（键盘 H = Home / 手柄 X）
local RETURN_ACTION_NAME = "AxeTycoonReturnToBase"

local BaseController = {
	Name = "BaseController",
	_myBase = nil :: Folder?,
	_started = false,
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

-- 把本地角色传送到自己基地的出生点
function BaseController:returnToBase()
	local base = self._myBase
	if not base or not base.Parent then
		return
	end

	local rootPart = LocalCharacter.rootPart
	if not rootPart or not rootPart.Parent then
		return
	end

	local spawnLocation = base:FindFirstChild("SpawnLocation") :: BasePart?
	if not spawnLocation then
		return
	end

	-- 抬高 3 study 避免卡入出生板
	rootPart.CFrame = spawnLocation.CFrame + Vector3.new(0, 3, 0)
end

-- AFK 回传：落在堆叠区 TouchedStacking，站在范围内可自动收取木头
function BaseController:returnToStacking()
	local base = self._myBase
	if not base or not base.Parent then
		return
	end

	local rootPart = LocalCharacter.rootPart
	if not rootPart or not rootPart.Parent then
		return
	end

	local stackingPart = BaseStackingAnchor.findPart(base)
	if stackingPart then
		rootPart.CFrame = BaseStackingAnchor.getStandCFrame(stackingPart) - stackingPart.CFrame.LookVector * 5
	else
		self:returnToBase()
	end
end

function BaseController:init()
	if self._started then
		return
	end
	self._started = true

	task.spawn(function()
		-- 等待服务端完成基地分配
		self._myBase = waitForMyBase()

		-- AFK 回传仅首次落点使用堆叠区，后续重生仍回 SpawnLocation
		local afkReturnPending = AfkTeleport.isLocalReturnJoin()
		local function placeCharacter()
			if afkReturnPending then
				afkReturnPending = false
				self:returnToStacking()
			else
				self:returnToBase()
			end
		end

		-- 当前角色已就绪则立即归位
		if LocalCharacter.rootPart then
			placeCharacter()
		end

		-- 角色每次重生后自动归位
		LocalCharacter.added:Connect(function(character)
			if character then
				placeCharacter()
			end
		end)
	end)

	-- 快捷键：键盘 H / 手柄 ButtonX
	ContextActionService:BindAction(RETURN_ACTION_NAME, function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			self:returnToBase()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.H, Enum.KeyCode.ButtonX)
end

return BaseController
