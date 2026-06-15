--!strict

--[[
	稀有度单色配置（端共享）。

	预制件缺失回退到 "1" 时，按 WoodConfig/AxeConfig 的 rarity 着色。
]]

local ColorEnum = require(script.Parent.Parent.Enums.ColorEnum)

local RarityColorConfig = {}

function RarityColorConfig.getColor(rarity: number): Color3
	local index = math.max(1, math.floor(rarity))
	return ColorEnum.SingleRarityColor[index] or ColorEnum.colors.White
end

-- 将模型所有 BasePart 设为指定稀有度颜色
function RarityColorConfig.applyToModel(model: Model, rarity: number)
	local color = RarityColorConfig.getColor(rarity)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Color = color
		end
	end
end

return RarityColorConfig
