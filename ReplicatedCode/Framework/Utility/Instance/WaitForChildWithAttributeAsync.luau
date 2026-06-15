--!strict

--[[
等待添加一个具有指定属性的子代，如果已经存在则返回一个
	属性的子节点。

	此函数不会跟踪子代属性的变化，因此在调用此函数或添加子代时，属性必须存在。
	属性必须存在。
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local findFirstChildWithAttribute = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Instance.FindFirstChildWithAttribute)

local function waitForChildWithAttributeAsync(parent: Instance, attributeName: string, attributeValue: any)
	local childWithAttribute = findFirstChildWithAttribute(parent, attributeName, attributeValue)

	while not childWithAttribute do
		parent.ChildAdded:Wait()
		childWithAttribute = findFirstChildWithAttribute(parent, attributeName, attributeValue)
	end

	return childWithAttribute :: Instance
end

return waitForChildWithAttributeAsync

