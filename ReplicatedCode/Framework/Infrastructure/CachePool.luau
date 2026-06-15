local CollectionService = game:GetService("CollectionService")

local PoolFolder = Instance.new("Folder")
PoolFolder.Name = "Pool"
PoolFolder.Parent = script
local tablei = table.insert
local tabler = table.remove

local CachePool = {}

local CLEAN_INTERVAL = 60  -- 清理循环间隔（秒）
local OBJECT_TIMEOUT = 120 -- 对象闲置超过此时长则销毁（秒）

local MAX_MODEL_COUNT = 2
local MAX_OTHER_COUNT = 4

local objectPool = {}

-- 懒启动标记：首次 freeObject 时才创建清理协程，避免池从未使用时浪费线程
local _cleanLoopStarted = false

local function startCleanLoop()
	if _cleanLoopStarted then return end
	_cleanLoopStarted = true
	task.spawn(function()
		while true do
			task.wait(CLEAN_INTERVAL)
			local now = os.clock()
			for key, objects in pairs(objectPool) do
				local validObjects = {}
				for _, obj in ipairs(objects) do
					if now - obj.lastUseTime < OBJECT_TIMEOUT then
						table.insert(validObjects, obj)
					else
						obj.Object:Destroy()
					end
				end
				objectPool[key] = validObjects
			end
		end
	end)
end

local function clearAllTags(object: Instance)
	for _, tag in pairs(CollectionService:GetTags(object)) do
		CollectionService:RemoveTag(object, tag)
	end
	for name in pairs(object:GetAttributes()) do
		object:SetAttribute(name, nil)
	end
end

-- Model 实例走更低的上限，其余（Part、Tool 等）走更高上限
local function isModel(object: Instance): boolean
	return object:IsA("Model")
end

function CachePool.getObject(key: string, prefabe: Instance)
	if not objectPool[key] then
		objectPool[key] = {}
	end
	local entry = tabler(objectPool[key])
	if not entry then
		return prefabe:Clone()
	end
	entry.lastUseTime = os.clock()
	return entry.Object
end

function CachePool.freeObject(key: string, object: Instance)
	if not (object and object:IsDescendantOf(game)) then return end

	clearAllTags(object)

	local objectList = objectPool[key]
	local maxCount = isModel(object) and MAX_MODEL_COUNT or MAX_OTHER_COUNT

	if #objectList < maxCount then
		object.Parent = PoolFolder
		tablei(objectPool[key], {
			Object = object,
			lastUseTime = os.clock(),
		})
		-- 首次归还对象时才启动清理协程
		startCleanLoop()
	else
		object:Destroy()
	end
end

return CachePool
