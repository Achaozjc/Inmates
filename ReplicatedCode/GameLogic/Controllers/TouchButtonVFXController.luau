--!strict

--[[
	触碰按钮粒子特效控制器（客户端表现）。

	职责：监听服务端 RemoteEventKey.TouchButtonVFX（参数为按钮名，仅在对应业务
	「成功」后发送，如购买/合成/收钱/升级/卸木/领群组奖励成功），在自己基地
	TouchedButtons 下同名按钮位置克隆 ReplicatedStorage/Instances/Prefabs/VFX
	对应预制体并发射粒子：

	- BuyAxe_1/5/25/100 → BuyVFX + SFX/Purchase
	- Merge             → MergeVFX + SFX/Whoosh
	- Upgrade           → UpgradeVFX + SFX/Rebirth
	- Group             → GroupVFX + SFX/CashCollect
	- CollectMoney      → CashVFX + SFX/CashCollect
	- Storage           → DepositVFX + SFX/TryOnRemove

	预制体为透明锚定 Part，内含 Enabled=false 的 ParticleEmitter，
	发射数量读取美术在发射器上配置的 EmitCount 属性（缺省 DEFAULT_EMIT_COUNT），
	支持 EmitDelay 属性延迟发射；播放完毕后自动销毁克隆体。

	说明：仅本地可见；是否触发由服务端业务结果决定（失败不播放），
	服务端触碰已做去抖，客户端无需重复去抖。
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Framework = ReplicatedStorage.ReplicatedCode.Framework
local GameLogic = ReplicatedStorage.ReplicatedCode.GameLogic

local Network = require(Framework.Core.Network)
local RemoteEventKey = require(GameLogic.SharedConstants.Keys.RemoteEventKey)
local AttributeEnum = require(GameLogic.Shared.Enums.AttributeEnum)

-- 按钮名 → VFX 预制体名（BuyAxe_* 按前缀单独处理）
local BUTTON_VFX_MAP: { [string]: string } = {
	Merge = "MergeVFX",
	Upgrade = "UpgradeVFX",
	Group = "GroupVFX",
	CollectMoney = "CashVFX",
	Storage = "DepositVFX",
}

local BUY_AXE_PREFIX = "BuyAxe_"
local BUY_VFX_NAME = "BuyVFX"

local DEFAULT_EMIT_COUNT = 15 -- 发射器未配置 EmitCount 属性时的发射数量
local CLONE_LIFETIME = 2 -- 克隆体存活时长（秒），需覆盖最长粒子 Lifetime + EmitDelay

local localPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() :: Player

local TouchButtonVFXController = {
	Name = "TouchButtonVFXController",
	_started = false,
}

local function findMyBase(): Folder?
	local world = Workspace:FindFirstChild("World")
	if not world then
		return nil
	end
	for _, child in world:GetChildren() do
		if child:IsA("Folder") and string.match(child.Name, "^Base_%d+$") then
			if child:GetAttribute(AttributeEnum.OwnerId) == localPlayer.UserId then
				return child
			end
		end
	end
	return nil
end

-- 按钮名解析对应 VFX 预制体名；无对应则返回 nil
local function resolveVfxName(buttonName: string): string?
	if string.sub(buttonName, 1, #BUY_AXE_PREFIX) == BUY_AXE_PREFIX then
		return BUY_VFX_NAME
	end
	return BUTTON_VFX_MAP[buttonName]
end

local function getVfxFolder(): Instance?
	local instances = ReplicatedStorage:FindFirstChild("Instances")
	local prefabs = instances and instances:FindFirstChild("Prefabs")
	return prefabs and prefabs:FindFirstChild("VFX")
end

-- 在按钮位置克隆预制体并触发所有发射器 Emit，播放完自动销毁
local function playVfx(prefab: BasePart, button: BasePart)
	local clone = prefab:Clone()
	clone.CFrame = button.CFrame
	clone.Parent = Workspace

	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("ParticleEmitter") then
			local emitter = descendant
			local emitCount = tonumber(emitter:GetAttribute("EmitCount")) or DEFAULT_EMIT_COUNT
			local emitDelay = tonumber(emitter:GetAttribute("EmitDelay")) or 0
			if emitDelay > 0 then
				task.delay(emitDelay, function()
					if emitter.Parent then
						emitter:Emit(emitCount)
					end
				end)
			else
				emitter:Emit(emitCount)
			end
		end
	end

	task.delay(CLONE_LIFETIME, function()
		clone:Destroy()
	end)
end

local nameList = {
	["CollectMoney"] = "Touch_Collection",
	["Storage"] = "Touch_Collection",
	["Upgrade"] = "Touch_Collection",
	
	["Group"] = "Touch_Group",
	
	["BuyAxe_1"] = "Touch_Merge&Buy",
	["BuyAxe_5"] = "Touch_Merge&Buy",
	["BuyAxe_25"] = "Touch_Merge&Buy",
	["BuyAxe_100"] = "Touch_Merge&Buy",
	["Merge"] = "Touch_Merge&Buy",
}

-- 服务端通知某按钮业务成功：定位自己基地同名按钮并播放对应特效
local function onVfxRequested(buttonName: unknown)
	if type(buttonName) ~= "string" then
		return
	end

	local vfxName = resolveVfxName(buttonName)
	if not vfxName then
		return
	end

	local vfxFolder = getVfxFolder()
	local prefab = vfxFolder and vfxFolder:FindFirstChild(vfxName)
	if not prefab or not prefab:IsA("BasePart") then
		warn("[TouchButtonVFXController] 未找到 VFX 预制体: " .. vfxName)
		return
	end

	local base = findMyBase()
	local name = nameList[buttonName]
	local buttonsFolder = base and base:FindFirstChild(name)
	local button = buttonsFolder and buttonsFolder:FindFirstChild(buttonName)
	if not button or not button:IsA("BasePart") then
		return
	end

	if buttonName == "CollectMoney" or buttonName == "Group" then
		SoundService.SFX.CashCollect:Play()
	elseif buttonName == "Storage" then
		SoundService.SFX.TryOnRemove:Play()
	elseif buttonName == "Merge" then
		SoundService.SFX.Whoosh:Play()
	elseif buttonName == "Upgrade" then
		SoundService.SFX.Rebirth:Play()
	elseif string.sub(buttonName, 1, #BUY_AXE_PREFIX) == BUY_AXE_PREFIX then
		SoundService.SFX.Purchase:Play()
	end

	playVfx(prefab, button)
end

function TouchButtonVFXController:init()
	if self._started then
		return
	end
	self._started = true

	Network.connectEvent(RemoteEventKey.TouchButtonVFX, onVfxRequested)
end

return TouchButtonVFXController
