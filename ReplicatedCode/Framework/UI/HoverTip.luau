--!strict


local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Janitor = require(ReplicatedStorage.ReplicatedCode.Framework.Packages.Janitor)
local getViewportScale = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.UI.GetViewportScale)
local InputCategory = require(ReplicatedStorage.ReplicatedCode.Framework.Input.InputCategory)
local TouchEnabled = (UserInputService.PreferredInput == InputCategory.Touch)
local getInstance = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Instance.GetInstance)
local getCodeAsset = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Instance.GetCodeAsset)

local OFFSET = Vector2.new(20, 0)
local PIX = 20
local Camera = workspace.CurrentCamera
local udOffset, vector2 = UDim2.fromOffset, Vector2.new

local scale, viewportSize = getViewportScale()

local prefabFolder: Folder = getCodeAsset("UI", "HoverTip")
local Gui = (getInstance(prefabFolder, "HoverGui") :: any) :: ScreenGui

local HoverTip = {}

HoverTip.janitor = Janitor.new()
HoverTip.isHoveing = false



function HoverTip.framePosition(frame: GuiObject, frameSize : Vector2, offset: Vector2?)
	local MousePosition = UserInputService:GetMouseLocation() + (offset or OFFSET)
	-- 计算调整过后的位置
	local newPosition = vector2(MousePosition.X, MousePosition.Y)
	-- 边界检查并调整位置
	if newPosition.X + frameSize.X > viewportSize.X then
		newPosition = vector2(viewportSize.X - frameSize.X - PIX, newPosition.Y)
	end
	if newPosition.Y + frameSize.Y > viewportSize.Y then
		newPosition = vector2(newPosition.X, viewportSize.Y - frameSize.Y - PIX)
	end
	frame.Position = udOffset(newPosition.X / scale, newPosition.Y / scale)
end


local function hoverTouch(frame: Frame, root:GuiObject?)
	local MousePosition = UserInputService:GetMouseLocation() + OFFSET
	local frameSize = frame.AbsoluteSize

	local newPosition = vector2(MousePosition.X - frameSize.X / 1.5, MousePosition.Y - PIX)

	if newPosition.X < 0 then
		newPosition = vector2(0, newPosition.Y)
	end
	if newPosition.Y + frameSize.Y > viewportSize.Y then
		newPosition = vector2(newPosition.X, viewportSize.Y - frameSize.Y)
	end

	frame.Position = udOffset(newPosition.X / scale, newPosition.Y / scale)
end


local function hoverPC(frame: Frame)
	local frameSize = frame.AbsoluteSize 

	HoverTip.janitor:Add(UserInputService.InputChanged:Connect(function()
		HoverTip.framePosition(frame, frameSize)
	end), "Disconnect")
end




function HoverTip.hover(frame: Frame)
	if HoverTip.isHoveing then
		return
	end
	HoverTip.isHoveing = true

	if TouchEnabled then	
		hoverTouch(frame)
	else	
		hoverPC(frame)
	end

	frame.Visible = true
end



function HoverTip.clean()
	if not HoverTip.isHoveing then
		return
	end
	HoverTip.janitor:Cleanup()
	HoverTip.isHoveing = false
end



function HoverTip.init(parent: Instance)
	
	Gui.Parent = parent
	
	Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()	
		scale, viewportSize = getViewportScale()
	end)
	
	
end




return HoverTip
