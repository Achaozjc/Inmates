--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loop = require(ReplicatedStorage.ReplicatedCode.Framework.Utility.UI.Loop)

local LeaderElection = {
	_loops = {} :: { [string]: any },
}

function LeaderElection.startLoop(id: string, interval: number, updateFunction: (number) -> ())
	assert(not LeaderElection._loops[id], string.format("Loop already registered with id: %s", id))

	local loop = Loop.new(id, interval, updateFunction) :: any
	LeaderElection._loops[id] = loop

	loop:start()
end

return LeaderElection
