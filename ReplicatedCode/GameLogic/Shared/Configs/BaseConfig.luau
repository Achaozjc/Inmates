--!strict

-- 斧头大亨基地相关通用常量（端共享）
local BaseConfig = {
	CARRY_LIMIT = 300, -- 玩家背负木头件数上限
	GROUND_STACK_LIMIT = 300, -- 堆叠区木头件数上限
	BUTTON_DEBOUNCE = 0.4, -- 触碰按钮去抖（秒）
	FLOOR_COUNT = 10, -- 楼层数
	SLOTS_PER_FLOOR = 10, -- 每层槽位数
}

return BaseConfig
