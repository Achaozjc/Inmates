--!strict

--[[
	同端 BindableEvent 注册表。
	游戏层可以在启动时传入需要创建的信号名；框架不再直接依赖 GameLogic 分类表。
]]

export type SignalMap = { [string]: BindableEvent }

local NetSignals = {
	signals = {} :: SignalMap,
}

function NetSignals.createSignals(signalNames: { string }?)
	if not signalNames then
		return
	end

	for _, signalName in ipairs(signalNames) do
		if not NetSignals.signals[signalName] then
			NetSignals.signals[signalName] = Instance.new("BindableEvent")
		end
	end
end

function NetSignals.getSignal(signalName: string): BindableEvent
	local signal = NetSignals.signals[signalName]
	if not signal then
		signal = Instance.new("BindableEvent")
		NetSignals.signals[signalName] = signal
	end
	return signal
end

return NetSignals
