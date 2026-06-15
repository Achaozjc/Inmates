--!strict
-- 地形水面：客户端用于与相机高度比较（BGM 水下效果等），非物理精确

local Workspace = game:GetService("Workspace")

-- 当前关卡海面基准高度（Studs）
local BASE_WATER_Y_STUDS = 16

local TerrainWaterSurface = {}

-- 近似波纹高度，随 Terrain 的 WaterWaveSize / WaterWaveSpeed 变化，与渲染不必逐帧一致
local function waveHeightOffset(x: number, z: number): number
	local terrain = Workspace.Terrain
	local waveSize = terrain.WaterWaveSize
	local waveSpeed = terrain.WaterWaveSpeed
	if waveSize < 1e-4 then
		return 0
	end
	local t = os.clock()
	local amp = waveSize * 2.5
	local n1 = math.sin((x * 0.12 + z * 0.09) + t * waveSpeed * 0.25)
	local n2 = math.sin((x * 0.07 - z * 0.11) + t * waveSpeed * 0.18 + 1.7)
	return amp * (0.55 * n1 + 0.45 * n2)
end

function TerrainWaterSurface.isUnderwaterAt(worldPosition: Vector3): boolean
	local surfaceY = BASE_WATER_Y_STUDS + waveHeightOffset(worldPosition.X, worldPosition.Z)
	return worldPosition.Y < surfaceY
end

return TerrainWaterSurface
