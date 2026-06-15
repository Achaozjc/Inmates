local EffectFolder = game.Workspace.DebrisFolder.EffectFolder
local tweenService = game:GetService("TweenService")


function createSpiralEffect(model, startPoint,numInstances)
	-- 确保模型有PrimaryPart
	if not model.PrimaryPart then
		warn("模型必须有PrimaryPart")
		return
	end



	local radius = 20
	local height = 20
	local angleIncrement = (2 * math.pi) / numInstances
	local heightIncrement = height / numInstances

	for i = 0, numInstances - 1 do
		local angle = i * angleIncrement
		local newPosition = startPoint + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)

		-- Clone the model and set its position
		local newInstance = model:Clone() :: Model
		newInstance:ScaleTo(5)
		newInstance:PivotTo(CFrame.new(newPosition))
		newInstance.Parent = EffectFolder

		local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)

		local goalPosition = startPoint + Vector3.new(0, height, 0)

		local goal = {}
		goal.CFrame = CFrame.new(goalPosition) * CFrame.Angles(0,math.rad(180),0)

		tweenService:Create(newInstance.PrimaryPart, tweenInfo, goal):Play()
		
	end
end


return createSpiralEffect

---- 确保模型有PrimaryPart
--local prefab = workspace.YourPrefabModel  -- 替换为你的预制体模型

---- 调用函数生成一圈模型并让它们汇聚
--createSpiralFormation(prefab, 20, 10, 50)