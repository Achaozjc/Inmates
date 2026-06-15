local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Network = require(ReplicatedStorage.ReplicatedCode.Framework.Core.Network)
local RemoteEventName = require(ReplicatedStorage.ReplicatedCode.Framework.Core.Network.RemoteName.RemoteEventName)




local function customExplosion(position, radius, maxDamage)
	local explosion = Instance.new("Explosion")
	explosion.BlastPressure = 0 
	explosion.DestroyJointRadiusPercent = 0 
	explosion.BlastRadius = radius
	explosion.Position = position
	
	local modelsHit = {}

	explosion.Hit:Connect(function(hit : BasePart, distance : number)
		local parentModel = hit:FindFirstAncestorOfClass("Model") ::Model
	
		if parentModel then
			--if parentModel:GetAttribute(AttributeEnum.IsPlayer) then
			--	return  --不能是玩家
			--end
		
			if modelsHit[parentModel] then
				return
			end
		
			modelsHit[parentModel] = true

			local humanoid = parentModel:FindFirstChild("Humanoid")
			if not humanoid then
				return
			end
			
			local distanceFactor = distance / explosion.BlastRadius
			distanceFactor = 1 - distanceFactor 
			humanoid:TakeDamage(maxDamage * distanceFactor) 
			
			local player = Players:GetPlayerFromCharacter(parentModel)
			
			if not player then
				return
			end
			--local rootPart = parentModel:FindFirstChild("HumanoidRootPart") ::BasePart
			--if not rootPart then
			--	return
			--end
			---- 设置网络所有权为nil
			----rootPart:SetNetworkOwner(nil)
			
			--local direction = (position - rootPart.Position).Unit
			--local impulse = direction * 1000
			--rootPart:ApplyImpulseAtPosition(impulse, rootPart.Position)

			Network.fireClient(RemoteEventName.ExplosionHit,  player, position)
			
		end
	end)

	explosion.Parent = game.Workspace

	explosion.AncestryChanged:Connect(function()
		if not explosion.Parent then
			explosion:Destroy()
		end
	end)
end

return customExplosion

--[[[

local function customExplosion(position)
	local explosion = Instance.new("Explosion")
	explosion.Position = position
	explosion.Visible = false

	local attachment = Instance.new("Attachment")
	attachment.Position = position
	attachment.Parent = workspace.Terrain

	local particleEmitter = Instance.new("ParticleEmitter")
	particleEmitter.Enabled = false
	particleEmitter.Parent = attachment
	particleEmitter.Speed = NumberRange.new(5, 30)
	particleEmitter.SpreadAngle = Vector2.new(-90, 90)

	explosion.Parent = workspace
	particleEmitter:Emit(20)

	task.delay(5, function()
		if attachment then
			attachment:Destroy()
		end
	end)
end

customExplosion(Vector3.new(0, 10, 0))

]]

