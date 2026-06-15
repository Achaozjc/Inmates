--!strict

--[[
	模块：UISetup
	描述：加载并初始化 GameLogic/Guis 下的所有 GUI 逻辑模块。

	用法：UISetup.start(guisFolder, onLoaded?)
	  - guisFolder : GameLogic 层的 Guis 文件夹，由调用方注入，Framework 不硬编码路径。
	  - onLoaded   : 可选回调，所有 GUI 初始化完成后执行（如设置 UILoaded 属性）。

	模块约定：
	  - Guis 文件夹下的直接子级 ModuleScript 均会被加载（名称无限制，如 ShopGui、GUI_Store）。
	  - 设置 Attribute "Ignore" 可跳过加载；子文件夹（如 Templates）不会被扫描。
	  - 设置 Attribute "EarlyListen" 的模块会在 UILoaded 前提前执行 listen（用于通知类 GUI）。

	预制体约定（参考 dingdong）：
	  - ScreenGui 视觉预制体放在 StarterGui，名称与 layerId 一致。
	  - 玩家加入后 Roblox 自动复制到 PlayerGui；各 GUI 模块在 init/start 中通过
	    BindStarterGui 或 GuiBase:bindScreenGui() 绑定，不要从 CodeAssets 克隆整页 UI。
	  - CodeAssets 仅用于小组件预制体（Button、HoverTip 等），不用于整页 ScreenGui。
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GamepadMouseDisabler = require(ReplicatedStorage.ReplicatedCode.Framework.UI.GamepadMouseDisabler)
local Loader = require(ReplicatedStorage.ReplicatedCode.Framework.Core.Loader)

local UISetup = {}

-- 未标记 EarlyListen 时的兼容回退（按优先级）
local EARLY_LISTEN_FALLBACK_NAMES = { "NotifyGui", "GUI_Notify" }

type UILayer = {
	init: ((any) -> ())?,
	listen: ((any) -> ())?,
}

local function shouldLoadGuiModule(module: Instance): boolean
	return module:IsA("ModuleScript") and module:GetAttribute("Ignore") ~= true
end

local function resolveEarlyListenGuiName(guisFolder: Folder, guis: { [string]: UILayer }): string?
	for _, module in guisFolder:GetChildren() do
		if shouldLoadGuiModule(module) and module:GetAttribute("EarlyListen") == true then
			return module.Name
		end
	end

	for _, name in ipairs(EARLY_LISTEN_FALLBACK_NAMES) do
		if guis[name] then
			return name
		end
	end

	return nil
end

function UISetup.load()
end

function UISetup.start(guisFolder: Folder, onLoaded: (() -> ())?)
	GamepadMouseDisabler.start()
	UISetup.load()

	local guis: { [string]: UILayer } = {}
	for _, module in guisFolder:GetChildren() do
		if shouldLoadGuiModule(module) then
			guis[module.Name] = require(module :: ModuleScript)
		end
	end

	Loader.ParallelInit(guis, "init")

	-- 通知监听需要先于 UILoaded 完成，避免开局服务端 toast 被 UnreliableRemoteEvent 丢弃
	local earlyListenGuiName = resolveEarlyListenGuiName(guisFolder, guis)
	local earlyListenGui = if earlyListenGuiName then guis[earlyListenGuiName] else nil
	if earlyListenGui and type(earlyListenGui.listen) == "function" then
		earlyListenGui.listen(earlyListenGui)
	end

	local asyncGuis: { [string]: UILayer } = {}
	for name, gui in pairs(guis) do
		if name ~= earlyListenGuiName then
			asyncGuis[name] = gui
		end
	end

	Loader.SpawnAll(asyncGuis, "listen")

	if onLoaded then
		onLoaded()
	end
end

return UISetup
