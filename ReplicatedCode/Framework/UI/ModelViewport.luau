--!strict

--[[
	创建 ViewportFrame，并根据模型尺寸和视口比例自动适配显示。
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local GetInstance = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Instance.GetInstance)
local getCodeAsset = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Instance.GetCodeAsset)
local createInstanceTree = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.Instance.CreateInstanceTree)




local prefabFolder: Folder = getCodeAsset("UI", "ModelViewport")
local prefabInstance: ViewportFrame = (GetInstance(prefabFolder, "ModelViewportPrefab") :: any) :: ViewportFrame

export type ModelViewportProperties = {
	model: Model?,
	fieldOfView: number?,
	lightingAmbient: Color3?,
	lightColor: Color3?,
	lightDirection: Vector3?,
	distance :number?,
	zoom: number?,
	offset: Vector3?,
	lookOffset: Vector3?,
	size: UDim2?,
	unitId: number?,
	angle: CFrame?,
	modelAngle: CFrame?,
	fitPrimaryPart: boolean?,
	fitVisibleParts: boolean?,
	fitBoundsPadding: number?,
}

local DEFAULT_FIELD_OF_VIEW = 20
local DEFAULT_LIGHTING_AMBIENT = Color3.fromRGB(255, 255, 255)
local DEFAULT_LIGHT_COLOR = Color3.fromRGB(255, 255, 255)
local DEFAULT_LIGHT_DIRECTION = Vector3.new(1, 1, 1)

local DEFAULT_UP_OFFSET = Vector3.new(0, 1, 0)
-- 取景平移（同时偏移相机与注视点）：+Y 让模型在画面中下移，-Y 上移；默认不平移
local DEFAULT_LOOK_OFFSET = Vector3.zero
local DEFAULT_DISTANCE = 0
-- 缩放倍数：>1 拉近相机使模型更大，<1 推远使其更小（1 = 刚好适配视口）
local DEFAULT_ZOOM = 1
local DEFAULT_SIZE = UDim2.fromScale(1,1)

local ModelViewport = {}
ModelViewport.__index = ModelViewport

export type ClassType = typeof(setmetatable(
	{} :: {
		_fieldOfView: number,
		_instance: ViewportFrame,
		_model: Model?,
		_camera: Camera?,
		_modelName: string,
		_modelCFrame: CFrame?,
		_modelSize: Vector3?,
		_distance:number,
		_zoom: number,
		_offset: Vector3,
		_lookOffset: Vector3,
		_size :UDim2?,
		_angle: CFrame,
		_modelAngle: CFrame,
		_fitPrimaryPart: boolean,
		_fitVisibleParts: boolean,
		_fitBoundsPadding: number,
	},
	ModelViewport
	))

function ModelViewport.new(properties: ModelViewportProperties): ClassType
	local self = setmetatable({
		_fieldOfView = properties.fieldOfView or DEFAULT_FIELD_OF_VIEW,
		_instance = prefabInstance:Clone(),
		_modelName = "",
		_model = nil,
		_camera = nil,
		_modelCFrame = nil,
		_modelSize = nil,
		_distance = properties.distance or DEFAULT_DISTANCE,
		_zoom = properties.zoom or DEFAULT_ZOOM,
		_offset = properties.offset or DEFAULT_UP_OFFSET,
		_lookOffset = properties.lookOffset or DEFAULT_LOOK_OFFSET,
		_size = properties.size or DEFAULT_SIZE,
		_angle = properties.angle or CFrame.identity,
		_modelAngle = properties.modelAngle or CFrame.identity,
		_fitPrimaryPart = properties.fitPrimaryPart or false,
		_fitVisibleParts = properties.fitVisibleParts or false,
		_fitBoundsPadding = properties.fitBoundsPadding or 1,
	}, ModelViewport) :: ClassType

	if properties.model then
		self:setModel(properties.model)
	end

	self:_setup(properties)

	return self
end

local function _getVisiblePartsBounds(model: Model): (CFrame?, Vector3?)
	local minPoint: Vector3? = nil
	local maxPoint: Vector3? = nil

	for _, inst in ipairs(model:GetDescendants()) do
		if not inst:IsA("BasePart") or inst.Transparency >= 1 then
			continue
		end

		local halfSize = inst.Size * 0.5
		for x = -1, 1, 2 do
			for y = -1, 1, 2 do
				for z = -1, 1, 2 do
					local point = inst.CFrame:PointToWorldSpace(Vector3.new(
						halfSize.X * x,
						halfSize.Y * y,
						halfSize.Z * z
					))
					if minPoint then
						minPoint = Vector3.new(
							math.min((minPoint :: Vector3).X, point.X),
							math.min((minPoint :: Vector3).Y, point.Y),
							math.min((minPoint :: Vector3).Z, point.Z)
						)
						maxPoint = Vector3.new(
							math.max((maxPoint :: Vector3).X, point.X),
							math.max((maxPoint :: Vector3).Y, point.Y),
							math.max((maxPoint :: Vector3).Z, point.Z)
						)
					else
						minPoint = point
						maxPoint = point
					end
				end
			end
		end
	end

	if not minPoint or not maxPoint then
		return nil, nil
	end

	local center = ((minPoint :: Vector3) + (maxPoint :: Vector3)) * 0.5
	local size = (maxPoint :: Vector3) - (minPoint :: Vector3)
	return CFrame.new(center), size
end


function ModelViewport.setModel(self: ClassType, prefab: Model)
	self._modelName = prefab.Name
	local model = prefab:Clone() :: Model
	model:PivotTo(CFrame.identity)
	
	if self._modelAngle ~= CFrame.identity then
		model:PivotTo(self._modelAngle)
	end
	-- 计算用于“适配视口”的模型信息：
	-- 如果开启了 fitPrimaryPart 参数并且模型设置了 PrimaryPart，则使用 PrimaryPart.Size 替代包围盒大小，
	-- 这样可以强制统一同类模型在 Viewport 里的相对大小。
	local modelCFrame, boundingSize = model:GetBoundingBox()
	if self._fitVisibleParts then
		local visibleCFrame, visibleSize = _getVisiblePartsBounds(model)
		if visibleCFrame and visibleSize then
			modelCFrame = visibleCFrame
			boundingSize = visibleSize * math.max(1, self._fitBoundsPadding)
		end
	end
	local primaryPart = model.PrimaryPart
	local primarySize: Vector3?
	if not self._fitVisibleParts and self._fitPrimaryPart and primaryPart and primaryPart:IsA("BasePart") then
		primarySize = primaryPart.Size
		modelCFrame = primaryPart.CFrame
	end
	self._modelCFrame = modelCFrame
	self._modelSize = if primarySize then primarySize else boundingSize
	
	model.Parent = self._instance:FindFirstChild("WorldModel")
	self._model = model
end

function ModelViewport.setParent(self: ClassType, parent: Instance)
	self._instance.Parent = parent
end


function ModelViewport.changeModel(self: ClassType, prefab: Model)
	if self._model then
		self._model:Destroy()
	end
	self:setModel(prefab)

	self:_updateCameraAngle()
end

function ModelViewport.setVisible(self: ClassType, visible: boolean)
	self._instance.Visible = visible
end

function ModelViewport.setAngle(self: ClassType, angle: CFrame)
	self._angle = angle
	if self._model then
		self:_updateCameraAngle()
	end
end

function ModelViewport.setModelAngle(self: ClassType, angle: CFrame)
	self._modelAngle = angle
	if self._model then
		self._model:PivotTo(angle)
		self._modelCFrame, self._modelSize = self._model:GetBoundingBox()
		self:_updateCameraAngle()
	end
end


function ModelViewport._getModel(self: ClassType)
	return self._model
end

function ModelViewport._buildTree(self: ClassType, properties: ModelViewportProperties)
	self._instance.Ambient = properties.lightingAmbient or DEFAULT_LIGHTING_AMBIENT
	self._instance.LightColor = properties.lightColor or DEFAULT_LIGHT_COLOR
	self._instance.LightDirection = properties.lightDirection or DEFAULT_LIGHT_DIRECTION
	self._instance.Size = properties.size or DEFAULT_SIZE
	-- 相机对象不会复制，所以运行时创建，而不是放在预制体里。
	local camera = createInstanceTree({
		className = "Camera",
		properties = {
			FieldOfView = self._fieldOfView,
			FieldOfViewMode = Enum.FieldOfViewMode.Vertical,
		},
	})
	camera.Parent = self._instance
	self._instance.CurrentCamera = camera

	self._camera = camera
end

function ModelViewport._setup(self: ClassType, properties: ModelViewportProperties)
	self:_buildTree(properties)

	-- 为了确保对象始终适合，我们需要更新摄像机的方向
	-- 每当帧的纵横比发生变化时，我们都需要更新相机的方向。
	-- 我们不需要存储此连接，因为当 ViewportFrame
	-- 销毁时就会断开连接。
	self._instance:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if self._model then
			self:_updateCameraAngle()
		end	
	end)
	if self._model then
		self:_updateCameraAngle()
	end	
end

function ModelViewport.pivotModel(self: ClassType, cFrame: CFrame)
	local model = self._model :: Model
	model:PivotTo(cFrame)
end

function ModelViewport.getModelPivot(self: ClassType): CFrame
	local model = self._model :: Model
	return model:GetPivot()
end

function ModelViewport.setLight(self: ClassType, bool: boolean)
	if bool then
		self._instance.ImageColor3 = Color3.fromRGB(255, 255, 255)
	else
		self._instance.ImageColor3 = Color3.fromRGB(0, 0, 0)
	end	
end




function ModelViewport.destroy(self: ClassType)
	if self._model then
		self._model:Destroy()
		self._model = nil
	end
	self._camera = nil
	self._instance:Destroy()
end



function ModelViewport._updateCameraAngle(self: ClassType)
	-- 我们相机的视野模式是垂直模式，这意味着水平视野
	-- 由长宽比决定
	local aspectRatio = self._instance.AbsoluteSize.X / self._instance.AbsoluteSize.Y
	local verticalFOV = math.rad(self._fieldOfView)
	-- 修正水平 FOV 计算公式
	local horizontalFOV = 2 * math.atan(math.tan(verticalFOV / 2) * aspectRatio)

	-- 我们试图找出摄像机需要后退的距离，以适应视图中给定方向上物体的大小。
	-- 要做到这一点，我们需要求解一个直角三角形的相邻边，该直角三角形的大小/2 与 FOV/2 的 theta 相对：
	--       视野
	--       /|\
	--      / | \
	--     /  |D \
	--    /   |I  \
	--   /    |S   \
	--  /     |T    \
	-- /______|______\
	--       尺寸
	local modelSize = self._modelSize :: Vector3
	local zOrx = math.max(modelSize.X, modelSize.Z)
	local distanceToFitHorizontal = (0.5 * zOrx) / math.tan(0.5 * horizontalFOV)
	local distanceToFitVertical = (0.5 * modelSize.Y) / math.tan(0.5 * verticalFOV)

	-- 为确保对象适合，我们将选取水平和垂直距离中的最大值
	local distanceToFit = math.max(distanceToFitHorizontal, distanceToFitVertical)

	-- 然后，我们应用模型深度的一半，这样我们就可以从物体的外边缘开始往回走了
	-- zoom 缩放适配距离：zoom 越大相机越近、模型越大（zoom=1 即刚好适配）
	local totalDistance = (distanceToFit + (0.5 * modelSize.Z)) / self._zoom + (self._distance or 5)
	local modelCFrame = self._modelCFrame :: CFrame
	modelCFrame = modelCFrame * self._angle

	local cameraTarget = modelCFrame * CFrame.new(0, 0, -totalDistance)
	

	local camera = self._camera :: Camera
	-- lookOffset 同时平移相机与注视点，整体平移取景（不引入透视倾斜）
	camera.CFrame = CFrame.lookAt(
		cameraTarget.Position + self._offset + self._lookOffset,
		modelCFrame.Position + self._lookOffset
	)
end

return ModelViewport
