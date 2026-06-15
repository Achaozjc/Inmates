local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeatherCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.WeatherCategory)


export type LightingProperties = {
	AtmosphereColor : Color3?,
	AtmosphereDecay : Color3?,
	AtmosphereGlare : number?,
	AtmosphereHaze : number?,
	
	AtmosphereDensity : number,
	AtmosphereOffset : number,
	Brightness: number,
	CloudsCover: number,
	CloudsDensity: number,
	
	
	GrassDirection: Vector3,
	WaterWaveSize: number,
	WaterWaveSpeed	: number,
}


local WeatherConfig = {
	[WeatherCategory.Clear] = {
		AtmosphereDensity = 0.12,      -- 空气通透，能见度极高
		AtmosphereOffset = 0.4,        -- 适当远景层次感
		Brightness = 3.0,              -- 晴天最亮
		CloudsCover = 0.0,             -- 无云
		CloudsDensity = 0.0,
		WaterWaveSize = 0.12,          -- 水面平静
		WaterWaveSpeed = 2,
	},

	[WeatherCategory.Windy] = {
		AtmosphereDensity = 0.18,      -- 轻微扬尘，整体清晰
		AtmosphereOffset = 0.15,
		Brightness = 2.5,              -- 云层略遮阳光
		CloudsCover = 0.55,            -- 中等云量，不过于压抑
		CloudsDensity = 0.45,
		WaterWaveSize = 0.25,          -- 风浪较大
		WaterWaveSpeed = 14,

		isWindy = true,                -- 启用 Trail 风线特效
	},

	[WeatherCategory.Foggy] = {
		AtmosphereDensity = 0.42,      -- 中雾：仍有雾感，远景略糊但可辨
		AtmosphereOffset = 0,          -- 雾从地面开始，不留底部空隙
		AtmosphereHaze = 2.0,          -- 低层雾气核心参数：越大雾越浓（略降以抬能见度）
		AtmosphereGlare = 0.55,         -- 光源周围产生雾中光晕（略弱减少糊脸感）
		AtmosphereColor = Color3.fromRGB(210, 215, 220), -- 雾天偏冷灰白
		AtmosphereDecay = Color3.fromRGB(180, 185, 190), -- 远景衰减偏蓝灰
		Brightness = 1.75,              -- 雾天略提亮，便于辨认地形与物体
		CloudsCover = 0.65,            -- 中厚云层配合地面雾气
		CloudsDensity = 0.5,
		WaterWaveSize = 0.08,          -- 雾天水面极平静
		WaterWaveSpeed = 3,
	},

	[WeatherCategory.Rain] = {
		AtmosphereDensity = 0.28,      -- 雨中水汽，略显朦胧
		AtmosphereOffset = 0.05,
		Brightness = 1.5,              -- 乌云蔽日
		CloudsCover = 0.88,            -- 厚云层
		CloudsDensity = 0.55,
		WaterWaveSize = 0.32,          -- 雨滴激起涟漪
		WaterWaveSpeed = 16,

		isRaining = true,
		isRainingIntensity = 0.35,     -- 普通雨强度（0~1，值越大雨越大）
	},

	[WeatherCategory.Snow] = {
		AtmosphereDensity = 0.3,       -- 雪天略有雾感，但不压抑
		AtmosphereOffset = 0.05,
		AtmosphereHaze = 0.8,          -- 轻微雪雾，增加冬季氛围
		Brightness = 2.0,              -- 雪面反光，但阴云偏暗
		CloudsCover = 0.85,
		CloudsDensity = 0.65,
		WaterWaveSize = 0.08,          -- 水面趋于平静，接近结冰
		WaterWaveSpeed = 4,

		isSnowing = true,
		isSnowingIntensity = 0.65,     -- 中等密度降雪，视觉饱满
	},

	[WeatherCategory.Tornado] = {
		AtmosphereDensity = 0.35,      -- 龙卷风扬尘，能见度受限
		AtmosphereOffset = 0,
		Brightness = 1.6,              -- 龙卷风天色阴沉，不宜偏亮
		CloudsCover = 0.95,
		CloudsDensity = 0.82,
		WaterWaveSize = 0.45,          -- 狂浪
		WaterWaveSpeed = 28,

		isTornado = true,
	},

	[WeatherCategory.Rainbow] = {
		AtmosphereDensity = 0.15,      -- 雨后放晴，空气清新
		AtmosphereOffset = 0.4,        -- 远景层次感强
		Brightness = 2.8,              -- 接近晴天亮度
		CloudsCover = 0.15,            -- 残留少量云，彩虹背景
		CloudsDensity = 0.1,
		WaterWaveSize = 0.18,          -- 雨后水面渐平
		WaterWaveSpeed = 5,

		isRainbow = true,
	},

	[WeatherCategory.Thunderstorm] = {
		AtmosphereDensity = 0.38,      -- 雷暴压迫感强
		AtmosphereOffset = 0,
		Brightness = 1.3,              -- 最暗，雷暴乌云压顶
		CloudsCover = 1.0,             -- 完全云覆盖
		CloudsDensity = 0.88,          -- 极厚风暴云
		WaterWaveSize = 0.55,          -- 波涛汹涌
		WaterWaveSpeed = 28,

		isRaining = true,
		isThundering = true,
		isRainingIntensity = 1.2,     -- 雷暴大雨（比普通雨强得多）
	},
} :: {[WeatherCategory.EnumType]: any}

return WeatherConfig
