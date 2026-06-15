local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NotifyCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.NotifyCategory)

local ColorEnum = {}

ColorEnum.colors = {
	Green = Color3.fromRGB(85, 255, 0),
	White = Color3.fromRGB(255, 255, 255),
	LightWhite = Color3.fromRGB(243, 243, 243),
	LightGray = Color3.fromRGB(180, 180, 180),
	Gray = Color3.fromRGB(100, 100, 100),
	Black = Color3.fromRGB(0, 0, 0),
	LBlack = Color3.fromRGB(46, 46, 46),
	Red = Color3.fromRGB(255, 79, 79),
	LRed = Color3.fromRGB(255, 116, 116),
	Blue = Color3.fromRGB(57, 184, 241),
	Yellow = Color3.fromRGB(255, 255, 127),
	Orange = Color3.fromRGB(255, 170, 0),
	DarkGray = Color3.fromRGB(50, 50, 50),
	DarkGreen = Color3.fromRGB(0, 85, 0),
	BrightRed = Color3.fromRGB(210, 0, 0),
	lightBlue = Color3.fromRGB(62, 255, 249),
	Purple = Color3.fromRGB(255, 0, 127),
}

ColorEnum.Notify = {
	[NotifyCategory.Warn] = Color3.fromRGB(255, 170, 0),
	[NotifyCategory.Success] = Color3.fromRGB(0, 255, 127),
	[NotifyCategory.Error] = Color3.fromRGB(255, 56, 56),
} :: { [NotifyCategory.EnumType]: Color3 }

ColorEnum.SingleRarityColor = {

	Color3.fromRGB(250, 250, 250),
	Color3.fromRGB(85, 255, 127), -- 绿色
	Color3.fromRGB(74, 232, 254), -- 浅蓝色
	Color3.fromRGB(170, 170, 255), -- 淡紫色
	Color3.fromRGB(255, 215, 0), -- 橙色
	Color3.fromRGB(255, 83, 83), -- 红色
	Color3.fromRGB(255, 102, 153), -- 彩虹（偏红，避免过粉）
	Color3.fromRGB(0, 255, 204), -- 极光青（稀有度 8，区别于金色和彩虹）
}

ColorEnum.Chest = {
	[1] = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)), 
		ColorSequenceKeypoint.new(1, Color3.fromRGB(147, 149, 152)),
	}),
	[2] = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 255, 127)), 
		ColorSequenceKeypoint.new(1, Color3.fromRGB(41, 170, 0)),
	}),
	[3] = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(127, 196, 255)), 
		ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 101, 255)),
	}),
	[4] = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(183, 127, 255)), 
		ColorSequenceKeypoint.new(1, Color3.fromRGB(121, 0, 233)),
	}),
	[5] = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 247, 106)), 
		ColorSequenceKeypoint.new(1, Color3.fromRGB(233, 176, 0)),
	}),
	[6] = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 148, 127)), 
		ColorSequenceKeypoint.new(1, Color3.fromRGB(233, 0, 19)),
	}),
}

ColorEnum.RarityColor = {

	[1] = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)), -- 普通：偏亮白
		ColorSequenceKeypoint.new(1, Color3.fromRGB(232, 234, 238)), -- 末端略冷灰
	}),

	[2] = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(72, 238, 118)), -- 绿：略深
		ColorSequenceKeypoint.new(1, Color3.fromRGB(108, 255, 145)), -- 末端略亮
	}),

	[3] = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(62, 215, 242)), -- 蓝：略饱和
		ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 245, 255)), -- 末端略浅青
	}),

	[4] = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(152, 152, 248)), -- 紫：略深
		ColorSequenceKeypoint.new(1, Color3.fromRGB(192, 192, 255)), -- 末端略亮
	}),

	[5] = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(248, 198, 0)), -- 金橙：略深
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 228, 72)), -- 末端略亮
	}),

	[6] = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(238, 68, 68)), -- 红：略沉
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 102, 102)), -- 末端略亮
	}),

	[7] = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 117, 195)),
		ColorSequenceKeypoint.new(0.1510416716337204, Color3.fromRGB(255, 166, 71)),
		ColorSequenceKeypoint.new(0.3072916567325592, Color3.fromRGB(255, 232, 63)),
		ColorSequenceKeypoint.new(0.4965277910232544, Color3.fromRGB(159, 255, 91)),
		ColorSequenceKeypoint.new(0.6649305820465088, Color3.fromRGB(112, 226, 255)),
		ColorSequenceKeypoint.new(0.8385416865348816, Color3.fromRGB(205, 147, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 117, 195)),
	}),

	-- 稀有度 8：极光渐变（最高阶）
	[8] = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(126, 255, 229)),
		ColorSequenceKeypoint.new(0.2, Color3.fromRGB(0, 255, 204)),
		ColorSequenceKeypoint.new(0.42, Color3.fromRGB(205, 255, 246)),
		ColorSequenceKeypoint.new(0.65, Color3.fromRGB(78, 218, 255)),
		ColorSequenceKeypoint.new(0.85, Color3.fromRGB(112, 255, 178)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 255, 204)),
	}),
}

-- 斧子 Billboard NameLabel 渐变（24 稀有度各一条 ColorSequence）
local function axeTwoTone(c0: Color3, c1: Color3): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, c0),
		ColorSequenceKeypoint.new(1, c1),
	})
end

local function axeMultiTone(keypoints: { { number | Color3 } }): ColorSequence
	local sequenceKeypoints = table.create(#keypoints)
	for index, keypoint in keypoints do
		sequenceKeypoints[index] = ColorSequenceKeypoint.new(keypoint[1] :: number, keypoint[2] :: Color3)
	end
	return ColorSequence.new(sequenceKeypoints)
end

ColorEnum.Axe = {
	[1] = ColorEnum.RarityColor[1],
	[2] = ColorEnum.RarityColor[2],
	[3] = ColorEnum.RarityColor[3],
	[4] = ColorEnum.RarityColor[4],
	[5] = ColorEnum.RarityColor[5],
	[6] = ColorEnum.RarityColor[6],
	[7] = ColorEnum.RarityColor[7],
	[8] = ColorEnum.RarityColor[8],
	[9] = axeTwoTone(Color3.fromRGB(118, 255, 148), Color3.fromRGB(52, 200, 98)),
	[10] = axeTwoTone(Color3.fromRGB(72, 220, 165), Color3.fromRGB(28, 160, 120)),
	[11] = axeTwoTone(Color3.fromRGB(64, 210, 190), Color3.fromRGB(20, 150, 165)),
	[12] = axeTwoTone(Color3.fromRGB(72, 185, 255), Color3.fromRGB(28, 120, 220)),
	[13] = axeTwoTone(Color3.fromRGB(98, 140, 255), Color3.fromRGB(48, 82, 210)),
	[14] = axeTwoTone(Color3.fromRGB(130, 108, 255), Color3.fromRGB(78, 52, 205)),
	[15] = axeTwoTone(Color3.fromRGB(168, 98, 255), Color3.fromRGB(110, 48, 210)),
	[16] = axeTwoTone(Color3.fromRGB(210, 88, 255), Color3.fromRGB(145, 38, 205)),
	[17] = axeTwoTone(Color3.fromRGB(255, 120, 190), Color3.fromRGB(220, 72, 140)),
	[18] = axeTwoTone(Color3.fromRGB(255, 96, 120), Color3.fromRGB(210, 38, 72)),
	[19] = axeTwoTone(Color3.fromRGB(255, 148, 72), Color3.fromRGB(220, 96, 28)),
	[20] = axeTwoTone(Color3.fromRGB(255, 198, 72), Color3.fromRGB(220, 150, 28)),
	[21] = axeMultiTone({
		{ 0, Color3.fromRGB(255, 120, 180) },
		{ 0.33, Color3.fromRGB(255, 220, 96) },
		{ 0.66, Color3.fromRGB(120, 230, 255) },
		{ 1, Color3.fromRGB(200, 140, 255) },
	}),
	[22] = axeMultiTone({
		{ 0, Color3.fromRGB(120, 255, 220) },
		{ 0.25, Color3.fromRGB(72, 180, 255) },
		{ 0.5, Color3.fromRGB(160, 120, 255) },
		{ 0.75, Color3.fromRGB(255, 120, 220) },
		{ 1, Color3.fromRGB(255, 210, 120) },
	}),
	[23] = axeMultiTone({
		{ 0, Color3.fromRGB(180, 120, 255) },
		{ 0.2, Color3.fromRGB(255, 120, 180) },
		{ 0.45, Color3.fromRGB(255, 210, 96) },
		{ 0.7, Color3.fromRGB(120, 255, 210) },
		{ 1, Color3.fromRGB(255, 160, 255) },
	}),
	[24] = axeMultiTone({
		{ 0, Color3.fromRGB(255, 248, 200) },
		{ 0.15, Color3.fromRGB(255, 210, 96) },
		{ 0.35, Color3.fromRGB(255, 140, 180) },
		{ 0.55, Color3.fromRGB(140, 220, 255) },
		{ 0.75, Color3.fromRGB(200, 160, 255) },
		{ 1, Color3.fromRGB(255, 248, 200) },
	}),
} :: { [number]: ColorSequence }

return ColorEnum
