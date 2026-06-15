local ConnectFrame = {}


local function creatConnect()
	local connector = Instance.new("Frame")
	connector.BackgroundColor3 = Color3.fromRGB(255, 255, 255) -- 红色连接线
	connector.Transparency = 0.5
	connector.BorderSizePixel = 0 -- 无边框
	return connector
end


local function calculateCenterOffset(frame: GuiObject)
	local absPos = Vector2.new(frame.Position.X.Offset, frame.Position.Y.Offset)
	local absSize = Vector2.new(frame.Size.X.Offset, frame.Size.Y.Offset)

	local anchorOffset = Vector2.new(
		absSize.X * frame.AnchorPoint.X,
		absSize.Y * frame.AnchorPoint.Y
	)

	return absPos + (absSize / 2) - anchorOffset
end

function ConnectFrame.Offset(frame1: GuiObject, frame2: GuiObject, parent: GuiObject, prefab: GuiObject?)
	local connector = prefab and prefab:Clone() or creatConnect()
	connector.AnchorPoint = Vector2.new(0.5, 0.5)
	-- 获取 frame1 和 frame2 的中心坐标
	local center1 = calculateCenterOffset(frame1)
	local center2 = calculateCenterOffset(frame2)
	-- 计算两个中心之间的距离和中点
	local distance = (center2 - center1).Magnitude
	local midPoint = (center1 + center2) / 2

	-- 设置连接器的 Size 和位置
	connector.Size = UDim2.new(0, distance, 0, 5) -- 你可以根据需要调整宽度
	connector.Position = UDim2.fromOffset(midPoint.X, midPoint.Y)

	-- 计算旋转角度并设置
	local angle = math.atan2(center2.Y - center1.Y, center2.X - center1.X)
	connector.Rotation = math.deg(angle)

	-- 将连接器添加到父级
	connector.Parent = parent
end

local function calculateCenterScale(frame: GuiObject, parentSize: UDim2)
	local position = frame.Position
	local size = frame.Size
	local absPos = Vector2.new(
		position.X.Scale * parentSize.X + position.X.Offset,
		position.Y.Scale * parentSize.Y + position.Y.Offset
	)
	local absSize = Vector2.new(
		size.X.Scale * parentSize.X + size.X.Offset,
		size.Y.Scale * parentSize.Y + size.Y.Offset
	)

	local anchorOffset = Vector2.new(
		absSize.X * frame.AnchorPoint.X,
		absSize.Y * frame.AnchorPoint.Y
	)

	return absPos + (absSize / 2) - anchorOffset
end


local function calculateCenterAbsolute(frame: GuiObject)
	-- 获取帧的绝对位置和绝对大小
	local absPos = frame.AbsolutePosition
	local absSize = frame.AbsoluteSize

	-- 计算根据 AnchorPoint 偏移后的中心
	local anchorOffset = Vector2.new(
		absSize.X * frame.AnchorPoint.X,
		absSize.Y * frame.AnchorPoint.Y
	)

	return absPos + (absSize / 2) - anchorOffset
end


function ConnectFrame.Scale(rootFrame: GuiObject, childFrame: GuiObject, prefab: GuiObject?)
	local connector = prefab and prefab:Clone() or creatConnect()
	connector.AnchorPoint = Vector2.new(0.5, 0.5)
	-- 计算 Frame1 和 Frame2 的中心坐标
	local parentSize = rootFrame.AbsoluteSize
	local parentPosition = rootFrame.AbsolutePosition
	-- 计算 Frame1 和 Frame2 的中心坐标
	local center1 = calculateCenterAbsolute(rootFrame)
	local center2 = calculateCenterAbsolute(childFrame)
	-- 计算两个中心之间的距离和中点
	local distance = (center2 - center1).Magnitude
	local midPoint = (center1 + center2) / 2

	-- 设置连接器的 Size 和姿态
	-- 将距离转换为 Scale
	local distanceScaleX = distance / parentSize.X -- 转换为 Scale
	connector.Size = UDim2.new(distanceScaleX, 0, 0, 5) -- 设置连接器的宽度为相对父级的宽度
	connector.Position = UDim2.new(0, midPoint.X - parentPosition.X, 0, midPoint.Y - parentPosition.Y)
	connector.Position = UDim2.new(0.5, 0, 0.5, 0) -- 再次调整以正确地居中

	-- 计算旋转角度并设置
	local angle = math.atan2(center2.Y - center1.Y, center2.X - center1.X)
	connector.Rotation = math.deg(angle) -- 设置连接器的旋转角度

	-- 更新连接器的位置为 Scale 坐标
	connector.Position = UDim2.new((midPoint.X - parentPosition.X) / parentSize.X, 0, (midPoint.Y - parentPosition.Y) / parentSize.Y, 0)
	
	---- 将连接器添加到父级
	connector.Parent = rootFrame
	
	return  connector
end

return ConnectFrame
