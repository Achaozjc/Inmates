--!strict
local RunService = game:GetService("RunService")

local ROTATION_SPEED = 360 / 15 -- degrees per second for ImageLabel
local LOADING_SPEED = 360 / 4   -- degrees per second for other GuiObjects


local UI_Glow = {}
UI_Glow.__index = UI_Glow

export type ClassType = typeof(setmetatable({} :: {
	_instance: GuiObject,
	_speed: number
	
}, UI_Glow))

local activeGlows = {} :: { ClassType }
local renderConnection: RBXScriptConnection? = nil

local function updateAll(dt: number)
	for _, glow in activeGlows do
		if glow._instance then
			glow._instance.Rotation = (glow._instance.Rotation + glow._speed * dt) % 360
		end
	end
end

local function startLoop()
	if not renderConnection then
		renderConnection = RunService.RenderStepped:Connect(updateAll)
	end
end

local function stopLoop()
	if renderConnection and #activeGlows == 0 then
		renderConnection:Disconnect()
		renderConnection = nil
	end
end

function UI_Glow.new(instance: GuiObject): ClassType
	local self = {
		_instance = instance,
		_speed = instance:IsA("ImageLabel") and ROTATION_SPEED or LOADING_SPEED
	}

	setmetatable(self, UI_Glow)
	
	self:setup()

	self:listen()

	return self
end

function UI_Glow.setup(self: ClassType)

	
end


function UI_Glow.scale(self: ClassType)

end



function UI_Glow.listen(self: ClassType)	
	table.insert(activeGlows, self)
	startLoop()
end



function UI_Glow.destroy(self: ClassType)
	local index = table.find(activeGlows, self)
	if index then
		table.remove(activeGlows, index)
		stopLoop()
	end
end

return UI_Glow
