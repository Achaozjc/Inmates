--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimateUI = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.UI.AnimateUI)

local GetInstance = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Instance.GetInstance)
local getCodeAsset = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Instance.GetCodeAsset)

local prefabFolder: Folder = getCodeAsset("Effects", "DialogueBillboardUI")
local DialogueBillboardPrefab = (GetInstance(prefabFolder, "DialogueBillboardPrefab") :: any) :: BillboardGui

local DialogueBillboardUI = {}
DialogueBillboardUI.__index = DialogueBillboardUI

export type ClassType = typeof(setmetatable(
	{} :: {

		_billboard: BillboardGui,
		_textLabel: TextLabel,
	},
	DialogueBillboardUI
))

-- 这个是Npc和玩家头顶上显示的对话
function DialogueBillboardUI.new()
	local self = setmetatable({

		_billboard = DialogueBillboardPrefab:Clone(),
	}, DialogueBillboardUI)

	self._textLabel = self._billboard:WaitForChild("TextLabel") :: TextLabel

	return self
end

function DialogueBillboardUI.adornee(self: ClassType, instance: BasePart, name: string?)
	if name then
		self._billboard.Name = name
	end
	self._billboard.Adornee = instance
	self._billboard.Parent = instance
end

function DialogueBillboardUI.speekDialogue(self: ClassType, text: string, callback: (() -> ())?, _delay: number?)
	self._billboard.Enabled = true
	AnimateUI.typeWrite(self._textLabel, text, 0.02)

	--if _delay then
	--	task.wait(_delay)
	--end
	if callback then
		callback()
	end
end

function DialogueBillboardUI.closeDialogue(self: ClassType)
	self._billboard.Enabled = false
end

function DialogueBillboardUI.destroy(self: ClassType)
	self._billboard:Destroy()
end

return DialogueBillboardUI
