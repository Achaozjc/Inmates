
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local UD2Scale = UDim2.fromScale


type WaveTransitionParams = {
	color: Color3?; -- color of squares (default white)
	width: number?; -- number of squares widthwise (default 10)
	waveDirection: Vector2?; -- direction vector of the wave (default (1,1))
	waveFunction: ((x: number, t: number) -> number)? -- shape of the wave (default below)
}

local function DefaultWaveFunction(x: number, t: number): number
	local l = 0.5 -- length of wave
	local edge = t * (1 + l)
	if x < edge - l then return 1
	elseif x > edge then return 0
	else return 0.5 + 0.5 * math.cos(math.pi / l * (x - edge + l))
	end
end

local SqaureWaveTransition = {}
SqaureWaveTransition.__index = SqaureWaveTransition

export type ClassType = typeof(setmetatable(
	{} :: {
		container: GuiObject,
		squares: {GuiObject},
		percents: {number},
		color: Color3;
		width: number; 
		height: number; 
		size: number,
		waveDirection :Vector2,
		waveFunction: ((x: number, t: number) -> number)
	},
	SqaureWaveTransition
	))


function SqaureWaveTransition.new(container: GuiObject, params: WaveTransitionParams?): ClassType
	
	local width = params and params.width and params.width or 10

	-- compute number of rows needed to cover screen
	local size = container.AbsoluteSize.X / width
	local height = math.ceil(container.AbsoluteSize.Y / size)
	
	local self = {
		container = container,
		squares = table.create(width*height) :: {GuiObject},
		percents = table.create(width*height) :: {number},
		color = params and params.color and params.color or Color3.new(1, 1, 1),
		width = width,
		height = height,
		size = size,
		waveDirection = params and params.waveDirection and params.waveDirection or Vector2.new(1, 1),
		waveFunction = params and params.waveFunction and params.waveFunction or DefaultWaveFunction
	}	
	setmetatable(self, SqaureWaveTransition)

	self:setup()
	
	return self 
end



function SqaureWaveTransition.setup(self: ClassType)	
	local shortest = math.huge
	local longest = -math.huge

	for r = 1, self.height do
		for c = 1, self.width do
			local pos = Vector2.new((c-1) * self.size, (r-1) * self.size)
			local frame = Instance.new("Frame")
			frame.AnchorPoint = Vector2.new(0.5, 0.5)
			-- we add 1 so there's overlap between frames (borders wouldn't let us make a 0,0 size)
			frame.Size = UDim2.fromOffset(self.size + 1, self.size + 1)
			frame.Position = UDim2.fromOffset(pos.X + self.size/2, pos.Y + self.size/2)
			frame.BackgroundColor3 = self.color
			frame.BorderSizePixel = 0
			frame.Parent = self.container
	
			-- project 2d position along direction line
			local percent = self.waveDirection:Dot(pos)
			if percent < shortest then shortest = percent end
			if percent > longest then longest = percent end

			local idx = (r - 1) * self.width + c

			self.squares[idx] = frame
			self.percents[idx] = percent
		end
	end

	-- remap projected positions on a scale from 0 to 1
	for i, s in ipairs(self.squares) do
		self.percents[i] = (self.percents[i] - shortest) / (longest - shortest)
	end
end

function SqaureWaveTransition._updateOne(self: ClassType, square: GuiObject, percent: number, alpha: number)
	local t = self.waveFunction(percent, alpha)
	square.Size = UDim2.fromOffset(t * (self.size + 1), t * (self.size + 1))
end

function SqaureWaveTransition._update(self: ClassType, alpha: number)
	for i, square in ipairs(self.squares) do
		self:_updateOne(square, self.percents[i], alpha)
	end
end


function SqaureWaveTransition.destroy(self: ClassType)
	for _, s in ipairs(self.squares) do
		s:Destroy()
	end
	self.squares = nil :: any
	self.percents = nil :: any
end



return SqaureWaveTransition

