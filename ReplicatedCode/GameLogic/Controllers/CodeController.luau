--!strict

--[[
	兑换码客户端状态：缓存已解锁 code 列表与全局点赞数，供 CodesGui / LikesCodesGui 共用。
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = ReplicatedStorage.ReplicatedCode.Framework

local Network = require(Framework.Core.Network)
local Signal = require(Framework.Packages.Signal)
local RemoteFunctionKey = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.RemoteFunctionKey)
local RemoteEventKey = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.RemoteEventKey)

local CodeController = {}

CodeController.changed = Signal.new()

local _releasedSet: { [string]: boolean } = {}
local _releasedList: { string } = {}
local _likes = 0
local _requesting = false

local function applyState(released: { string }, likes: number)
	_releasedSet = {}
	_releasedList = {}

	if typeof(released) == "table" then
		for _, code in ipairs(released) do
			if typeof(code) == "string" then
				local normalized = string.lower(code)
				if not _releasedSet[normalized] then
					_releasedSet[normalized] = true
					table.insert(_releasedList, normalized)
				end
			end
		end
		table.sort(_releasedList)
	end

	_likes = if typeof(likes) == "number" then likes else 0
	CodeController.changed:Fire()
end

function CodeController.hasState(): boolean
	return #_releasedList > 0 or _likes > 0
end

function CodeController.getLikes(): number
	return _likes
end

function CodeController.getReleasedList(): { string }
	return _releasedList
end

function CodeController.isReleased(code: string): boolean
	return _releasedSet[string.lower(code)] == true
end

function CodeController.applyServerState(payload: any)
	if typeof(payload) ~= "table" then
		return
	end
	applyState(payload.released or {}, payload.likes or 0)
end

function CodeController.requestStateAsync()
	if _requesting then
		return
	end
	_requesting = true
	task.spawn(function()
		local pcallOk, success, payload = Network.invokeServerAsync(RemoteFunctionKey.Code_GetReleased)
		_requesting = false
		if pcallOk and success and typeof(payload) == "table" then
			CodeController.applyServerState(payload)
		end
	end)
end

function CodeController.start()
	Network.connectEvent(RemoteEventKey.Code_ReleaseUpdate, function(released: { string }, likes: number)
		applyState(released, likes)
	end)

	task.delay(10, CodeController.requestStateAsync)
end

function CodeController.listen() end

return CodeController
