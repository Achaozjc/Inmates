--!nocheck

local ComponentCreator = require(script.ComponentCreator)

local Binder = {}
Binder.Components = {}

local function createComponents(folder: Folder)
	for _, module in ipairs(folder:GetDescendants()) do
		if module:IsA("ModuleScript") and not module:GetAttribute("Ignore") then
			local success, err = xpcall(function()
				local tag = module.Name
				local handle = require(module)
				local component = ComponentCreator.new(tag, handle)
				component:listen()
				Binder.Components[tag] = component
			end, debug.traceback)

			if not success then
				warn(string.format("[Binder] component load failed: %s\n%s", module:GetFullName(), tostring(err)))
			end
		end
	end
end

function Binder.getComponent(tag: string, model: Instance)
	if not Binder.Components[tag] then
		return nil
	end
	return Binder.Components[tag]:getComponentFromInstance(model)
end

-- componentsFolder 由 GameLogic 层在入口处传入，Framework 不硬编码任何业务路径
function Binder.initialize(componentsFolder: Folder)
	createComponents(componentsFolder)
end

return Binder
