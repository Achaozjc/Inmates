--[[

	ModuleScript for loading SkyPop lighting profiles during runtime.
	
	To load a profile, call `LightProfileLoad.loadLighting(folder)`.
	
	Example:
	
	local LightProfileLoad = require(ServerScriptService.LightProfileLoad)
	LightProfileLoad.loadLighting(ServerStorage.MyLightingProfile)
	
	---------------------------------------------------------------------------
	
	Author: sleitnick (https://github.com/Sleitnick)
	
--]]

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local getInstance = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Instance.GetInstance)
local Skys = ReplicatedStorage:WaitForChild("GamePlay"):WaitForChild("Instance"):WaitForChild("Skys") :: Folder

local IS_STUDIO = RunService:IsStudio()

local LightProfileLoad = {}

function LightProfileLoad.loadLighting(name: string)
	
	local folder = (getInstance(Skys, name) :: any) :: Folder
	
	
	if IS_STUDIO then
		-- Need to set to 'nil' instead of Destroy() in order
		-- for undo/redo support to work properly in Studio:
		for _, child in Lighting:GetChildren() do
			child.Parent = nil
		end
	else
		-- During runtime, just clear all:
		Lighting:ClearAllChildren()
	end

	-- Copy over all elements in the folder into Lighting:
	for _, v in folder:GetChildren() do
		v:Clone().Parent = Lighting
	end

	-- Write all attributes of the folder as properties of Lighting:
	for attrName, attrValue in folder:GetAttributes() do
		local success, err = pcall(function()
			Lighting[attrName] = attrValue
		end)

		if not success then
			warn(`failed to set lighting property "{attrName}": {err}`)
		end
	end
end

return LightProfileLoad

