export type GridAgent = {
	uid: string | number,
	position: { x: number, z: number }?,
}

local function visible(size, x, z)
	local part = script:WaitForChild("Part"):Clone()

	part.Size = Vector3.new(size,2,size)
	part.Position = Vector3.new(x * size, 1, z * size) -- 乘以格子大小以确保不重叠

	part.Parent = game.Workspace.DebrisFolder
	part.SurfaceGui.Frame.z.Text = "z = " .. z
	part.SurfaceGui.Frame.x.Text = "x = " .. x
end


local Grid = {}
Grid.__index = Grid

function Grid.new(gridSize :number?, cellSize :number?)
	local self = setmetatable({}, Grid)
	self.gridSize = gridSize or 100
	self.cellSize = cellSize or 20
	self.grid = {}
	 -- 计算偏移量
    local xOffset = self.gridSize / 2
	local zOffset = self.gridSize / 2
	
	self.offset = self.gridSize / (2 * self.cellSize)

	for x = -xOffset, xOffset do
        self.grid[x] = {}
		for z = -zOffset, zOffset do
			self.grid[x][z] = {} -- 每个格子初始为空表
			--visible(self.cellSize, x, z)
        end
    end
	return self
end


-- 添加对象到格子
function Grid:addObject(agent: GridAgent, position: Vector3)
	local x, z = self:positionToGrid(position)
	--table.insert(self.grid[x][z], agent)
	--agent.position = {x = x, z = z} -- 存储对象当前的网格位置
	if not self.grid[x][z][agent.uid] then
		self.grid[x][z][agent.uid] = agent
		agent.position = {x = x, z = z} -- 存储对象当前的网格位置
	end
end

-- 从旧位置移除对象
function Grid:removeObject(agent: GridAgent)
	local gridPos = agent.position
	--if gridPos then
	--	-- 查找并移除对象
	--	for i, obj :AgentCategory.EnumType in ipairs(self.grid[gridPos.x][gridPos.z]) do
	--		if obj.uid == agent.uid then
	--			table.remove(self.grid[gridPos.x][gridPos.z], i)
	--			break
	--		end
	--	end
	--end
	if gridPos then
		local agentUid = agent.uid
		if self.grid[gridPos.x][gridPos.z][agentUid] then
			self.grid[gridPos.x][gridPos.z][agentUid] = nil
		end
	end
end

-- 根据世界位置转化为格子位置
function Grid:positionToGrid(position: Vector3)
	local x = math.floor((position.X + self.offset ) / self.cellSize)
	local z = math.floor((position.Z + self.offset ) / self.cellSize)
	return x, z
end

function Grid:updateObjectPosition(agent, newPosition :Vector3)
	self:removeObject(agent) -- 从它当前的格子中移除
	self:addObject(agent, newPosition) -- 在新的格子中添加
end


function Grid:getNearbyObjects(position: Vector3, range)
	local nearbyObjects = {}
	local x, z = self:positionToGrid(position)

	if self.grid[x] and self.grid[x][z] then
		for _, agent in pairs(self.grid[x][z]) do
			table.insert(nearbyObjects, agent)
		end
	end
	--local startX, startZ = self:positionToGrid(position)
	--local endX, endZ = self:positionToGrid(position)

	--for x = math.max(1, startX), math.min(self.gridSize, endX) do
	--	for z = math.max(1, startZ), math.min(self.gridSize, endZ) do
	--		if self.grid[x] and self.grid[x][z] then
	--			for _, agent in ipairs(self.grid[x][z]) do
	--				table.insert(nearbyObjects, agent)
	--			end
	--		end
	--	end
	--end
	return nearbyObjects
end

return Grid
