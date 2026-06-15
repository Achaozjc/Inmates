export type EnumType = string


local WeatherCategory = {
	Clear = "Clear" :: "Clear", --晴天
	Windy = "Windy" :: "Windy", --风
	Foggy = "Foggy" :: "Foggy",  	--雾天
	Rain = "Rain" :: "Rain", --雨天
	
	
	Snow = "Snow" :: "Snow", 	--雪天
	Thunderstorm = "Thunderstorm" :: "Thunderstorm",  --雷雨天
	Tornado = "Tornado" :: "Tornado", --龙卷风
	Rainbow = "Rainbow" :: "Rainbow", --彩虹
}

return WeatherCategory
