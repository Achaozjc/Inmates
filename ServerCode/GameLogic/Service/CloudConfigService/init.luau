--!strict
-- 云端配置 Service：start 时在代码中创建 CloudConfigHolder（Folder）挂到 ReplicatedStorage，不依赖任何 Studio 实例；客户端从 ReplicatedStorage.CloudConfigHolder 读 Attribute

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")


local CloudConfig = require(script.CloudConfig)

-- 挂在 ReplicatedStorage 下独立目录，避免挂到 ReplicatedStorage.ReplicatedCode.GameLogic 导致磁盘同步冲突（Game 为磁盘同步目录）
local CLOUD_CONFIG_HOLDER_NAME = "CloudConfigHolder"

local CloudConfigService = {}

function CloudConfigService.start()
	if not RunService:IsServer() then
		return
	end

	local holder = script:FindFirstChild(CLOUD_CONFIG_HOLDER_NAME) ::any
	if not holder then
		holder = Instance.new("Folder") :: Folder
		holder.Name = CLOUD_CONFIG_HOLDER_NAME
		holder.Parent = script
	end

	CloudConfig.setAttributeHolder(holder)
	-- 可按需在此设置默认 key：CloudConfig.setDefaultValues({ DemoFlag = "default" })
	CloudConfig._pollForUpdates()
end

function CloudConfigService.listen()
	-- 无额外监听
end

function CloudConfigService.getValue(key: string)
	return CloudConfig.getValue(key)
end

function CloudConfigService.getValueChangedSignal(key: string)
	return CloudConfig.getValueChangedSignal(key)
end

-- 仅 Studio 写云用；生产环境勿在运行时调用
function CloudConfigService.setValueAsync(key: string, value: any)
	CloudConfig.setValueAsync(key, value)
end

-- 客户端读云端配置：从该 Instance 的 Attribute 读取，路径固定为 ReplicatedStorage.CloudConfigHolder
function CloudConfigService.getConfigHolder(): Instance?
	return ReplicatedStorage:FindFirstChild(CLOUD_CONFIG_HOLDER_NAME) or nil
end

return CloudConfigService
