--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CODE_ASSETS_TIMEOUT = 10

local function waitForChild(parent: Instance, childName: string): Instance
	local child = parent:WaitForChild(childName, CODE_ASSETS_TIMEOUT)
	assert(child, string.format("CodeAssets path missing: %s.%s", parent:GetFullName(), childName))
	return child
end

local codeAssetsRoot = waitForChild(waitForChild(ReplicatedStorage, "Instances"), "CodeAssets")

local function getCodeAsset<T>(...: string): T
	local current = codeAssetsRoot

	for _, childName in ipairs({ ... }) do
		current = waitForChild(current, childName)
	end

	return (current :: any) :: T
end

return getCodeAsset
