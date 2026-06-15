local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AudioController = require(ReplicatedStorage.ReplicatedCode.GameLogic.Controllers.AudioController)

local SOURCE_LOCALE = "en"
local translator = nil

local AnimateUI = {}

function AnimateUI.loadTranslator()
	pcall(function()
		translator = LocalizationService:GetTranslatorForPlayerAsync(Players.LocalPlayer)
	end)
	if not translator then
		pcall(function()
			translator = LocalizationService:GetTranslatorForLocaleAsync(SOURCE_LOCALE)
		end)
	end
end

function AnimateUI.typeWrite(guiObject, text, delayBetweenChars)
	guiObject.Visible = true
	guiObject.AutoLocalize = false
	local displayText = text

	-- Translate text if possible
	if translator then
		displayText = translator:Translate(guiObject, text) :: string
	end

	-- Replace line break tags so grapheme loop will not miss those characters
	displayText = displayText:gsub("<br%s*/>", "\n")
	-- 富文本
	--displayText = displayText:gsub("<[^<>]->", "")
	-- Set translated/modified text on parent
	guiObject.Text = displayText
	
	local index = 1
	local visibleCount = 0
	local length = #displayText

	while index <= length do
		local ch = displayText:sub(index, index)
		if ch == "<" then
			-- 遇到标签开始，找到对应的结束符 '>'
			local closeIdx = displayText:find(">", index)
			if closeIdx then
				-- 跳过整个标签
				index = closeIdx + 1
			else
				-- 标签没有结束，直接退出（或者处理错误）
				index = index + 1
			end
		else
			-- 纯文本字符，显示并触发音效
			visibleCount = visibleCount + 1
			guiObject.MaxVisibleGraphemes = visibleCount
			AudioController.playSFX("SpinClick")
			index = index + 1
			task.wait(delayBetweenChars)
		end
	end

	task.wait(1)
	
	--local index = 0
	--for first, last in utf8.graphemes(displayText) do
	--	index += 1
	--	guiObject.MaxVisibleGraphemes = index
	

	--	AudioController.playSFX("SpinClick")
	--	task.wait(delayBetweenChars)
	--end
	--task.wait(1)
end

return AnimateUI