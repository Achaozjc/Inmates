--!strict

local DialogueNodeBuilder = {}

type DialogueOption = {
	getLabel: (self: any) -> string,
}

type DialogueNode = {
	startText: ((self: any, ...any) -> any)?,
	options: { [number]: DialogueOption },
	callback: { [number]: (self: any, ...any) -> any },
	getCallback: (self: any, index: number, ...any) -> any,
}

function DialogueNodeBuilder.safeCallbackCall(callbackMap: { [number]: (any, ...any) -> any }, context: any, index: number, ...: any)
	local callback = callbackMap[index]
	if type(callback) ~= "function" then
		return {
			text = "这个选项暂时还没准备好。",
			returnToRoot = true,
		}
	end

	return callback(context, ...)
end

function DialogueNodeBuilder.create(nodeData: { [any]: any }): DialogueNode
	local node = table.clone(nodeData) :: DialogueNode

	function node.getCallback(self: any, index: number, ...: any)
		return DialogueNodeBuilder.safeCallbackCall(self.callback, self, index, ...)
	end

	return node
end

function DialogueNodeBuilder.createWithContext(nodeData: { [any]: any }, getContext: (self: any) -> any): DialogueNode
	local node = table.clone(nodeData) :: DialogueNode

	function node.getCallback(self: any, index: number, ...: any)
		local context = getContext(self)
		return DialogueNodeBuilder.safeCallbackCall(self.callback, context, index, ...)
	end

	return node
end

return DialogueNodeBuilder
