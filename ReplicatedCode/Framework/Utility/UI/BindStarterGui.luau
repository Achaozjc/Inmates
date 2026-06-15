--!strict

--[[
	从 StarterGui 克隆到 PlayerGui 的 ScreenGui 实例上绑定逻辑。

	Studio 要求：在 StarterGui 下放置与 screenGuiName 同名的 ScreenGui 预制体，
	玩家加入后 Roblox 会自动复制到 PlayerGui，本函数在 PlayerGui 中等待并返回该实例。
]]

local Players = game:GetService("Players")

local localPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() :: Player

local BindStarterGui = {}

function BindStarterGui.waitForScreenGui(screenGuiName: string, player: Player?): ScreenGui
	local targetPlayer = player or localPlayer
	local playerGui = targetPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local screenGui = playerGui:WaitForChild(screenGuiName) :: ScreenGui
	screenGui.Parent = playerGui
	return screenGui
end

return BindStarterGui
