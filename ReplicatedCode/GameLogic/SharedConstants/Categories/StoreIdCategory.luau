--!strict

export type StoreIdCategoryType = {
	Gamepass: { [string]: number },
	Product: { [string]: number },
}

-- 新项目不要沿用旧项目的付费 ID；上线前在这里重新配置。
local StoreIdCategory: StoreIdCategoryType = {
	Gamepass = {
		-- 三个通行证（Gamepass，一次性永久购买）。
		-- TODO: 替换为 Roblox 后台创建的通行证 ID（当前为占位 0，不会注册/弹窗）。
		AutoCollectCash = 1870090884, -- 自动收集钱：服务端定时把 PendingCash 自动领取为 Cash
		AutoCollectWood = 1870462842, -- 自动收集木料：服务端定时自动背木并卸入处理机
		DoubleWood = 1872242803, -- 双倍木料：入库时木料价值 ×2
	},
	Product = {
		-- 立即处理：付费后将处理机全部库存一次性转入 PendingCash，玩家自行 CollectMoney 领取。
		-- TODO: 替换为 Roblox 后台创建的开发者商品 ID（当前为占位 0，不会注册/弹窗）。
		InstantProcess = 3603710302,

		-- Cash 倍率：逐档付费（x2→x4→x7→x12→x20→x40），购买后永久提升现金倍率。
		-- TODO: 替换为 Roblox 后台创建的开发者商品 ID（当前为占位 0，不会注册/弹窗）。
		CashMultiplier2x = 3603736975,
		CashMultiplier4x = 3603737031,
		CashMultiplier7x = 3603737046,
		CashMultiplier12x = 3603737058,
		CashMultiplier20x = 3603737078,
		CashMultiplier40x = 3603737096,

		-- 付费金钱：逐档付费立即获得现金（倍率 × 拥有斧头数 ownedAxeCount），可重复购买。
		-- 三档对应 200 / 3000 / 300000 倍率（设计价 15 / 119 / 799 Robux）。
		-- TODO: 替换为 Roblox 后台创建的开发者商品 ID（当前为占位 0，不会注册/弹窗）。
		PayCash200 = 3603748657,
		PayCash3000 = 3603748672,
		PayCash300000 = 3603748685,

		-- 宝箱付费开启：Cash 不足时改用 Robux 直接开启对应稀有度宝箱，每个稀有度一个商品。
		-- TODO: 替换为 Roblox 后台创建的开发者商品 ID（当前为占位 0，不会注册/弹窗）。
		ChestOpenCommon = 3603739958,
		ChestOpenUncommon = 3603739972,
		ChestOpenRare = 3603739994,
		ChestOpenEpic = 3603740005,
		ChestOpenLegendary = 3603740012,
		ChestOpenMythic = 3603740020,
	},
}

return StoreIdCategory
