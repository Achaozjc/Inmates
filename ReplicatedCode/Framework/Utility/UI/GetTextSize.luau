--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local getViewportScale = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.UI.GetViewportScale)

local udim2 = UDim2.new


--local function getTextSize(label: TextLabel, isY:boolean?, scale: number?)
--	local minScale = scale or getViewportScale()
--	local params = Instance.new("GetTextBoundsParams")
--	params.Text = label.Text
	
--	params.Font = label.FontFace
	
--	local rich = label.RichText
--	params.RichText = rich
	
--	params.Size = rich and label.TextSize or label.TextSize / minScale
	
--	--local width = label.AbsoluteSize.X	
--	params.Width = math.huge--(isY) and math.huge or width
	
--	local textBounds = TextService:GetTextBoundsAsync(params)

--	textBounds = textBounds * minScale
	
--	if isY then
--		label.Size = udim2(label.Size.X.Scale, label.Size.X.Offset, label.Size.Y.Scale, textBounds.Y)
--	else
	
--		label.Size = udim2(label.Size.X.Scale, textBounds.X , label.Size.Y.Scale, label.Size.Y.Offset)
--	end
	
--end
local function getTextSize(label: TextLabel, isY: boolean?, scale: number?)
	local minScale = scale or getViewportScale()

	local text = label.Text
	local font = label.Font
	local textSize = label.TextSize


	local textBounds = TextService:GetTextSize(
		text, 
		textSize, 
		font, 
		Vector2.new(1000, 1000)
	)
	
	--local textSizeConstraint = label:FindFirstChild("UITextSizeConstraint") ::UITextSizeConstraint
	--if textSizeConstraint then
	--	textSizeConstraint.MaxTextSize = textSize * minScale * 1.2
	--end
	
	textBounds = textBounds / minScale / 2

	if isY then
		label.Size = UDim2.new(label.Size.X.Scale, label.Size.X.Offset, 0, textBounds.Y)
	else
		label.Size = UDim2.new(label.Size.X.Scale, textBounds.X, label.Size.Y.Scale, label.Size.Y.Offset)
	end
end


return getTextSize
