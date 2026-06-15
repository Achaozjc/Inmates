local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local getInstance = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Instance.GetInstance)
local Janitor = require(ReplicatedStorage.ReplicatedCode.Framework.Packages.Janitor)
local getCodeAsset = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Instance.GetCodeAsset)
local prefabFolder = getCodeAsset("Effects", "DialogueOptions") :: Folder
local prefab = (getInstance(prefabFolder, "DialogueOption") :: any) :: Frame

local tweenInfo = TweenInfo.new(0.25)

local DialogueOptions = {}
DialogueOptions.__index = DialogueOptions

export type ClassType = typeof(setmetatable({}::{
	_janitor:Janitor.Janitor,
	_instance:Frame,
	_button:TextButton,
	
},DialogueOptions))

function DialogueOptions.new()
	local self = {
		_janitor = Janitor.new(),
		_instance = prefab:Clone(),
		_button = nil
		
	}
	setmetatable(self,DialogueOptions)
	
	local button = (self._instance:WaitForChild("Button") :: any) :: TextButton
	self._button = button
	
	return self
end

function DialogueOptions.setData(self: ClassType, dialogue, npcName: string, index: number)
	self._instance.Visible = true
	local button = self._button
	local Label = (button :: any).TextFrame.Label :: TextLabel
	local Order = (button :: any).Order :: TextLabel
	

	Label.Text = string.format("\"%s\"", dialogue.text)
	Order.Text = string.format("%s |", tostring(index))
	local buttonMouserEnterConnect = button.MouseEnter:Connect(function()
		self._instance.Transparency = 0
		TweenService:Create(Label,tweenInfo,{Position = UDim2.fromScale(0.05,.5)}):Play()
	end)

	local buttonMouserLeaveConnect = button.MouseLeave:Connect(function()
		self._instance.Transparency = 0.5
		TweenService:Create(Label,tweenInfo,{Position = UDim2.fromScale(0,.5)}):Play()
	end)

	Label.Position = UDim2.fromScale(0.6,.5)
	TweenService:Create(Label,tweenInfo,{Position = UDim2.fromScale(0,.5)}):Play()
end

function  DialogueOptions.setOptionButtonCallback(self:ClassType,callback)
	self._janitor:Add(self._button.Activated:Connect(callback),"Disconnect") 
end

function DialogueOptions.clear(self:ClassType)
	self._janitor:Cleanup()
	self._instance.Visible = false
end

function DialogueOptions.setParent(self:ClassType,parent:GuiObject)
	self._instance.Parent = parent
end

function DialogueOptions.destroy(self:ClassType)
	self._janitor:Destroy()
end

return DialogueOptions
