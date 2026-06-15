--!strict

--[[
		搜索实例的子实例，返回第一个包含与给定名称和值相匹配的属性的子实例。
	属性的第一个子实例。
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Sift = require(ReplicatedStorage.ReplicatedCode.Framework.Packages.Sift)

local function findFirstChildWithAttribute(
	parent: Instance,
	attributeName: string,
	attributeValue: any
): Instance?
	local children = parent:GetChildren()
	local index = Sift.Array.findWhere(children, function(instance: Instance)
		return instance:GetAttribute(attributeName) == attributeValue
	end)

	return if index then children[index] else nil
end

return findFirstChildWithAttribute
