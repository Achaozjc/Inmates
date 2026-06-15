--!strict
-- 云端键值配置：由 CloudConfigService 注入 Attribute 容器并启动轮询，不依赖任何 Studio 实例（Holder 在 start 中代码创建）

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.ReplicatedCode.Framework.Packages.Signal)

local DATA_STORE_NAME = "_CloudConfig"
local DATA_STORE_KEY = "Configs"
local DATA_STORE_READ_INTERVAL = 60

local ALLOWED_VALUE_TYPES = {
	"number",
	"boolean",
	"string",
	"nil",
}

local configDataStore = RunService:IsServer() and DataStoreService:GetDataStore(DATA_STORE_NAME) :: GlobalDataStore

local CloudConfig = {
	_configAttributeHolder = nil :: Instance?,
	_changedSignals = {} :: { [string]: any },
	_polling = false,
	_updateInProgress = false,
}

function CloudConfig.setAttributeHolder(holder: Instance)
	assert(not not holder, "CloudConfig attribute holder cannot be nil")
	CloudConfig._configAttributeHolder = holder :: Instance
end

function CloudConfig._getHolder(): Instance
	local h = CloudConfig._configAttributeHolder
	assert(h ~= nil, "CloudConfig.setAttributeHolder must be called before use")
	return h
end

function CloudConfig._fetchValuesAsync()
	assert(RunService:IsServer(), "Keys can only be fetched on the server")

	local holder = CloudConfig._getHolder()
	local dataStore = configDataStore :: GlobalDataStore
	local success, result = pcall(function()
		return dataStore:GetAsync(DATA_STORE_KEY)
	end)

	if success and result then
		for key, value in result :: { [string]: any } do
			holder:SetAttribute(key, value)
		end
	end

	if not success then
		warn(string.format("Failed to fetch key values - %s", result))
	end
end

function CloudConfig._pollForUpdates()
	assert(not CloudConfig._polling, "CloudConfig module already initialized")
	CloudConfig._getHolder()

	task.spawn(function()
		while true do
			CloudConfig._fetchValuesAsync()
			task.wait(DATA_STORE_READ_INTERVAL)
		end
	end)

	CloudConfig._polling = true
end

function CloudConfig.setDefaultValues(defaults: { [string]: any })
	assert(RunService:IsServer(), "Config default values must be set on the server")

	local holder = CloudConfig._getHolder()
	for key, defaultValue in defaults do
		assert(
			table.find(ALLOWED_VALUE_TYPES, typeof(defaultValue)) ~= nil,
			string.format("Disallowed type '%s' for key: %s", typeof(defaultValue), key)
		)

		if holder:GetAttribute(key) ~= nil then
			warn(string.format("Config '%s' is already added", key))
		else
			holder:SetAttribute(key, defaultValue)
		end
	end
end

function CloudConfig.getValue(key: string)
	return CloudConfig._getHolder():GetAttribute(key)
end

function CloudConfig.getValueChangedSignal(key: string)
	local changedSignal = CloudConfig._changedSignals[key]
	if not changedSignal then
		changedSignal = Signal.new()
		CloudConfig._changedSignals[key] = changedSignal

		CloudConfig._getHolder():GetAttributeChangedSignal(key):Connect(function()
			changedSignal:Fire(CloudConfig._getHolder():GetAttribute(key))
		end)
	end

	return changedSignal
end

function CloudConfig.setValueAsync(key: string, value: any)
	assert(RunService:IsStudio(), "Keys must be set in studio")
	assert(not CloudConfig._updateInProgress, "Key update already in progress")
	assert(
		table.find(ALLOWED_VALUE_TYPES, typeof(value)) ~= nil,
		string.format("Disallowed type '%s' for key: %s", typeof(value), key)
	)

	CloudConfig._updateInProgress = true
	local oldValue: any = nil
	local dataStore = configDataStore :: GlobalDataStore
	local success, result = pcall(function()
		dataStore:UpdateAsync(DATA_STORE_KEY, function(oldConfig)
			local newConfig = oldConfig or {}
			oldValue = newConfig[key]
			newConfig[key] = value
			return newConfig
		end)
	end)
	CloudConfig._updateInProgress = false

	if success then
		print(string.format("Changed key '%s' from '%s' to '%s", key, tostring(oldValue), tostring(value)))
	else
		error(result)
	end
end

return CloudConfig
