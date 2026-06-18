--!strict

--[[
	基地堆叠区（TouchedStacking）查找与站立位姿，供 AFK 回传落点、教程引导等复用。
]]

local STAND_HEIGHT_OFFSET = 3
local STACKING_ANCHOR_NAME = "TouchedStacking"

local BaseStackingAnchor = {
	ANCHOR_NAME = STACKING_ANCHOR_NAME,
	STAND_HEIGHT_OFFSET = STAND_HEIGHT_OFFSET,
}

function BaseStackingAnchor.findPart(base: Instance): BasePart?
	local axeMachine = base:FindFirstChild("InmateMachine")
	local stacking = axeMachine and axeMachine:FindFirstChild(STACKING_ANCHOR_NAME)
	if stacking and stacking:IsA("BasePart") then
		return stacking
	end
	local found = base:FindFirstChild(STACKING_ANCHOR_NAME, true)
	return if found and found:IsA("BasePart") then found else nil
end

-- 站在堆叠区顶面中心，抬高避免卡入部件
function BaseStackingAnchor.getStandCFrame(anchorPart: BasePart): CFrame
	return anchorPart.CFrame * CFrame.new(0, anchorPart.Size.Y * 0.5 + STAND_HEIGHT_OFFSET, 0)
end

return BaseStackingAnchor
