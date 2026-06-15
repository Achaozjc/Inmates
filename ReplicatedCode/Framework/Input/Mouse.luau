-- Mouse
-- Stephen Leitnick
-- November 07, 2020
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Janitor = require(ReplicatedStorage.ReplicatedCode.Framework.Packages.Janitor)
local Signal = require(ReplicatedStorage.ReplicatedCode.Framework.Packages.Signal)


local UserInputService = game:GetService("UserInputService")

local RAY_DISTANCE = 1000
local DOUBLECLICKTHRESHOLD = 0.5 -- 连续点击的时间间隔阈值（以秒为单位）
--[=[
	@class Mouse
	@client

	The Mouse class is part of the Input package.

	```lua
	
	```
]=]
local Mouse = {}
Mouse.__index = Mouse



export type ClassType = typeof(setmetatable(
	{} :: {


	},
	Mouse
	))

--[=[
	@within Mouse
	@prop LeftDown Signal
	@tag Event
]=]
--[=[
	@within Mouse
	@prop LeftUp Signal
	@tag Event
]=]
--[=[
	@within Mouse
	@prop RightDown Signal
	@tag Event
]=]
--[=[
	@within Mouse
	@prop RightUp Signal
	@tag Event
]=]
--[=[
	@within Mouse
	@prop Scrolled Signal<number>
	@tag Event
	```lua
	mouse.Scrolled:Connect(function(scrollAmount) ... end)
	```
]=]

--[=[
	@return Mouse

	Constructs a new mouse input capturer.

	```lua
	local mouse = Mouse.new()
	```
]=]
function Mouse.new()
	local self = setmetatable({}, Mouse)

	self._janitor = Janitor.new()

	self.LeftDown = Signal.new()
	self.LeftUp = Signal.new()
	self.RightDown = Signal.new()
	self.RightUp = Signal.new()
	self.Scrolled = Signal.new()
	self.DoubleClick = Signal.new()
	
	self:ListenInput()
	
	return self
end

function Mouse:ListenInput()
	
	local lastClickTime = nil -- 用于记录上一次点击的时间

	
	self._janitor:Add(UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local currentTime = os.clock()
			if lastClickTime and (currentTime - lastClickTime) <= DOUBLECLICKTHRESHOLD then
				self.DoubleClick:Fire() -- Fire the double-click event
			else
				self.LeftDown:Fire() -- Fire the single left-click event
			end
			lastClickTime = currentTime
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			self.RightDown:Fire()
		end
	end), "Disconnect")

	self._janitor:Add(UserInputService.InputEnded:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self.LeftUp:Fire()
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			self.RightUp:Fire()
		end
	end), "Disconnect")

	self._janitor:Add(UserInputService.InputChanged:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			self.Scrolled:Fire(input.Position.Z)
		end
	end), "Disconnect")


	if UserInputService.TouchEnabled then
		self._janitor:Add(UserInputService.TouchTap:Connect(function(touchPositions, processed)
			if processed then
				return
			end

			local currentTime = os.clock() -- 获取当前时间
			if lastClickTime and (currentTime - lastClickTime) <= DOUBLECLICKTHRESHOLD then
				-- 如果两次点击时间间隔小于阈值，则认为是连续点击
				--print("Double Tapped!")
				self.DoubleClick:Fire()

				-- 这里添加你的代码，以响应连续点击事件
			end
			lastClickTime = currentTime -- 更新最后一次点击的时间
		end), "Disconnect")

	end
	
end



--[=[
	Checks if the left mouse button is down.
]=]
function Mouse:IsLeftDown(): boolean
	return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
end

--[=[
	Checks if the right mouse button is down.
]=]
function Mouse:IsRightDown(): boolean
	return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
end

--[=[
	Gets the screen position of the mouse.
]=]
function Mouse:GetPosition(): Vector2
	return UserInputService:GetMouseLocation()
end

--[=[
	Gets the delta screen position of the mouse. In other words, the
	distance the mouse has traveled away from its locked position in
	a given frame (see note about mouse locking below).

	:::info Only When Mouse Locked
	Getting the mouse delta is only intended for when the mouse is locked. If the
	mouse is _not_ locked, this will return a zero Vector2. The mouse can be locked
	using the `mouse:Lock()` and `mouse:LockCenter()` method.
]=]
function Mouse:GetDelta(): Vector2
	return UserInputService:GetMouseDelta()
end

--[=[
	Returns the viewport point ray for the mouse at the current mouse
	position (or the override position if provided).
]=]
function Mouse:GetRay(overridePos: Vector2?): Ray
	local mousePos = overridePos or UserInputService:GetMouseLocation()
	local viewportMouseRay = workspace.CurrentCamera:ViewportPointToRay(mousePos.X, mousePos.Y)
	return viewportMouseRay
end

--[=[
	Performs a raycast operation out from the mouse position (or the
	`overridePos` if provided) into world space. The ray will go
	`distance` studs forward (or 1000 studs if not provided).

	Returns the `RaycastResult` if something was hit, else returns `nil`.

	Use `Raycast` if it is important to capture any objects that could be
	hit along the projected ray. If objects can be ignored and only the
	final position of the ray is needed, use `Project` instead.

	```lua
	local params = RaycastParams.new()
	local result = mouse:Raycast(params)
	if result then
		print(result.Instance)
	else
		print("Mouse raycast did not hit anything")
	end
	```
]=]
function Mouse:Raycast(raycastParams: RaycastParams, distance: number?, overridePos: Vector2?): RaycastResult?
	local viewportMouseRay = self:GetRay(overridePos)
	local result = workspace:Raycast(
		viewportMouseRay.Origin,
		viewportMouseRay.Direction * (distance or RAY_DISTANCE),
		raycastParams
	)
	return result
end

--[=[
	Gets the 3D world position of the mouse when projected forward. This would be the
	end-position of a raycast if nothing was hit. Similar to `Raycast`, optional
	`distance` and `overridePos` arguments are allowed.
	
	Use `Project` if you want to get the 3D world position of the mouse at a given
	distance but don't care about any objects that could be in the way. It is much
	faster to project a position into 3D space than to do a full raycast operation.

	```lua
	local params = RaycastParams.new()
	local distance = 200

	local result = mouse:Raycast(params, distance)
	if result then
		-- Do something with result
	else
		-- Raycast failed, but still get the world position of the mouse:
		local worldPosition = mouse:Project(distance)
	end
	```
]=]
function Mouse:Project(distance: number?, overridePos: Vector2?): Vector3
	local viewportMouseRay = self:GetRay(overridePos)
	return viewportMouseRay.Origin + (viewportMouseRay.Direction.Unit * (distance or RAY_DISTANCE))
end

--[=[
	Locks the mouse in its current position on screen. Call `mouse:Unlock()`
	to unlock the mouse.

	:::caution Must explicitly unlock
	Be sure to explicitly call `mouse:Unlock()` before cleaning up the mouse.
	The `Destroy` method does _not_ unlock the mouse since there is no way
	to guarantee who "owns" the mouse lock.
]=]
function Mouse:Lock()
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
end

--[=[
	Locks the mouse in the center of the screen. Call `mouse:Unlock()`
	to unlock the mouse.

	:::caution Must explicitly unlock
	See cautionary in `Lock` method above.
]=]
function Mouse:LockCenter()
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
end

--[=[
	Unlocks the mouse.
]=]
function Mouse:Unlock()
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
end

--[=[
	Destroys the mouse.
]=]
function Mouse:Destroy()
	self._janitor:Destroy()
	self.LeftDown:DisconnectAll()
	self.LeftUp:DisconnectAll()
	self.RightDown:DisconnectAll()
	self.RightUp:DisconnectAll()
	self.Scrolled:DisconnectAll()
end

return Mouse

