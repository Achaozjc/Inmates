--!strict

--[[
	宝箱生产服务（服务端权威，仅产出数据）。

	由 WoodProductionService 在每次产木后调用 tryProduce：按斧头稀有度查出可掉落的宝箱等级
	（ChestConfig.AxeRarityToChest），以该宝箱的 spawnChance（5%）概率掉落。掉落时：
		1. 写入 ChestState（占用一个 ChestPlace 槽位，满仓则不生成）；
		2. fireAllClients(AxeTycoonSync, {kind="chestSpawn", ...}) 通知客户端做表现
		   （宝箱预制体物理滑到轨道 → 触碰 TouchedStacking → 码放到 ChestPlace 的 Attachment）；
		3. 起一个 existTime（100s）倒计时，到点移除数据并 fireAllClients chestExpire 让客户端销毁模型。

	宝箱模型只存在于客户端，服务端只维护数据（见 ChestState）。
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ReplicatedCode = ReplicatedStorage:WaitForChild("ReplicatedCode")
local ServerCode = ServerScriptService:WaitForChild("ServerCode")

local Network = require(ReplicatedCode.Framework.Core.Network)
local AxeConfig = require(ReplicatedCode.GameLogic.Shared.Configs.AxeConfig)
local ChestConfig = require(ReplicatedCode.GameLogic.Shared.Configs.ChestConfig)
local RemoteEventKey = require(ReplicatedCode.GameLogic.SharedConstants.Keys.RemoteEventKey)
local ChestState = require(ServerCode.GameLogic.Modules.AxeTycoon.ChestState)

local ChestProductionService = {}
local started = false

-- 到点移除某宝箱数据并通知客户端销毁模型
local function expireChest(userId: number, id: number)
	local removed = ChestState.removeChest(userId, id)
	if removed then
		Network.fireAllClients(RemoteEventKey.AxeTycoonSync, {
			kind = "chestExpire",
			id = id,
		})
	end
end

--[[
	尝试为一次产木掉落宝箱。
	userId      产木玩家
	axeModel    产木的斧子模型（客户端据此定位所属基地的 ChestPlace）
	axeCategory 斧头等级（AxeCategory 值）
]]
function ChestProductionService.tryProduce(userId: number, axeModel: Model, axeCategory: string)
	local axeInfo = AxeConfig.Axes[axeCategory]
	if not axeInfo then
		return
	end

	-- 该斧头是否对应可掉落的宝箱等级（稀有度 1 无掉落）
	local chestCategory = ChestConfig.getChestForAxeRarity(axeInfo.rarity)
	if not chestCategory then
		return
	end

	local chestCfg = ChestConfig.Chests[chestCategory]
	if not chestCfg then
		return
	end

	-- 存放位已满则不再生成
	if ChestState.count(userId) >= ChestConfig.PLACE_LIMIT then
		return
	end

	-- 概率判定
	if math.random() > chestCfg.spawnChance then
		return
	end

	local entry = ChestState.addChest(userId, chestCategory)
	if not entry then
		return
	end

	-- 通知所有客户端：生成一个宝箱并码放到 ChestPlace 的对应槽位
	Network.fireAllClients(RemoteEventKey.AxeTycoonSync, {
		kind = "chestSpawn",
		axe = axeModel,
		chest = chestCategory,
		id = entry.id,
		slot = entry.slot,
	})

	-- 存在时间倒计时：到点移除数据 + 销毁客户端模型
	local id = entry.id
	task.delay(chestCfg.existTime, function()
		expireChest(userId, id)
	end)
end

-- 玩家离开：清理其所有宝箱数据并通知客户端销毁残留模型
local function onPlayerRemoving(player: Player)
	for _, entry in ChestState.getChests(player.UserId) do
		Network.fireAllClients(RemoteEventKey.AxeTycoonSync, {
			kind = "chestExpire",
			id = entry.id,
		})
	end
	ChestState.clear(player.UserId)
end

function ChestProductionService.start()
	if started then
		return
	end
	started = true

	Players.PlayerRemoving:Connect(onPlayerRemoving)
end

return ChestProductionService
