--!strict

--[[
	新手教程服务（服务端，极简，仅负责存档）。

	引导流程与步骤推进全部在客户端 TutorialController 完成（软引导，不影响玩法权威逻辑）；
	服务端只监听 Tutorial_StepComplete，把对应步骤标记写入 PlayerData.Tutorial.newbie：
		BuyAxe           → buyAxeDone
		CollectWood      → collectWoodDone
		DepositWood      → depositWoodDone
		CollectCash      → collectCashDone
		UpgradeProcessor → upgradeDone
	幂等：已完成的步骤重复上报直接忽略。教程状态非关键数据，客户端上报可信度足够。
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ReplicatedCode = ReplicatedStorage:WaitForChild("ReplicatedCode")
local ServerCode = ServerScriptService:WaitForChild("ServerCode")

local Network = require(ReplicatedCode.Framework.Core.Network)
local RemoteEventKey = require(ReplicatedCode.GameLogic.SharedConstants.Keys.RemoteEventKey)
local TutorialStepKey = require(ReplicatedCode.GameLogic.SharedConstants.Keys.TutorialStepKey)
local PlayerDataKey = require(ReplicatedCode.GameLogic.SharedConstants.Keys.PlayerDataKey)
local PlayerDataServer = require(ServerCode.Framework.DataStore.PlayerData.PlayerDataServer)
local DebouncedPlayerSave = require(ServerCode.GameLogic.Modules.AxeTycoon.DebouncedPlayerSave)

-- 步骤键 → newbie 标记字段
local FLAG_BY_STEP: { [string]: string } = {
	[TutorialStepKey.BuyAxe] = "buyAxeDone",
	[TutorialStepKey.CollectWood] = "collectWoodDone",
	[TutorialStepKey.DepositWood] = "depositWoodDone",
	[TutorialStepKey.CollectCash] = "collectCashDone",
	[TutorialStepKey.UpgradeProcessor] = "upgradeDone",
}

local TutorialService = {}

local started = false

-- 客户端上报某步完成：校验步骤键后置标记（幂等）
local function onStepComplete(player: Player, stepKey: string)
	local flag = FLAG_BY_STEP[stepKey]
	if not flag then
		return
	end
	if not PlayerDataServer.hasLoaded(player) then
		return
	end

	local changed = false
	PlayerDataServer.updateValue(player, PlayerDataKey.Tutorial, function(tutorial)
		tutorial = if type(tutorial) == "table" then tutorial else {}
		local newbie = if type(tutorial.newbie) == "table" then tutorial.newbie else {}
		if newbie[flag] ~= true then
			newbie[flag] = true
			changed = true
		end
		tutorial.newbie = newbie
		return tutorial
	end)

	if changed then
		DebouncedPlayerSave.schedule(player)
	end
end

function TutorialService.start()
	if started then
		return
	end
	started = true

	Network.connectEvent(RemoteEventKey.Tutorial_StepComplete, onStepComplete, Network.t.string)
end

return TutorialService
