--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local getCodeAsset = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Instance.GetCodeAsset)

local codeAssetsRoot = getCodeAsset() :: Folder

local function getInstancePrefab(category: string, key: string): Instance?
	local folder = codeAssetsRoot:FindFirstChild(category)
	if not folder then
		warn("CodeAsset category missing:", category)
		return nil
	end

	local asset = folder:FindFirstChild(key)
	if not asset then
		warn("CodeAsset missing for category:", category, "key:", key)
	end

	return asset
end

return getInstancePrefab
