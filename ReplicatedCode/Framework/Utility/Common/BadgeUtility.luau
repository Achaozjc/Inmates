local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local BadgeService = game:GetService("BadgeService")
local RunService = game:GetService("RunService")

local BadgeKeys = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.BadgeKeys)
local BadgeEnum = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Enums.BadgeEnum)
local PlayerDataKey = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Keys.PlayerDataKey)
local PlayerDataServer = require(ServerScriptService.ServerCode.Framework.DataStore.PlayerData.PlayerDataServer)


local BadgeUtility = {}
local invalidBadgeIdCache: { [number]: true } = {}
local studioSkipWarned = false



local function checkingEarned(player: Player, badgeId:number)
	if invalidBadgeIdCache[badgeId] then
		return false
	end
	-- 检查玩家是否已获得该成就
	local success, hasBadge = pcall(BadgeService.UserHasBadgeAsync, BadgeService, player.UserId, badgeId)
	if not success then
		local err = tostring(hasBadge)
		if string.find(err, "badgeId is invalid or does not exist", 1, true) then
			-- 命中无效成就 id 后做会话级熔断，避免持续刷屏
			invalidBadgeIdCache[badgeId] = true
			warn("成就 id 无效，已停止重试", badgeId)
			return false
		end
		warn("检查玩家成就状态失败", err, badgeId)
	end
	if hasBadge then
		return true
	end
	return false
end

local function resolveBadgeIdByKey(badgeKey: string): number?
	local badgeId = BadgeEnum[badgeKey]
	if typeof(badgeId) ~= "number" then
		return nil
	end
	if badgeId <= 0 then
		return nil
	end
	return badgeId
end

local function hasClaimedInSave(player: Player, badgeKey: string): boolean
	local bucket = PlayerDataServer.getValue(player, PlayerDataKey.BadgeClaimed)
	return type(bucket) == "table" and bucket[badgeKey] == true
end

local function markClaimedInSave(player: Player, badgeKey: string)
	PlayerDataServer.updateValue(player, PlayerDataKey.BadgeClaimed, function(bucket)
		bucket = if type(bucket) == "table" then bucket else {}
		bucket[badgeKey] = true
		return bucket
	end)
end


function BadgeUtility.awardBadge(player: Player, badgeId:number): boolean
	if badgeId <= 0 then
		return false
	end
	if invalidBadgeIdCache[badgeId] then
		return false
	end
	if RunService:IsStudio() then
		if not studioSkipWarned then
			studioSkipWarned = true
			-- Studio 本地测试无法稳定验证线上成就，直接跳过避免误报
			warn("当前为 Studio 环境，已跳过成就发放")
		end
		return false
	end

	if checkingEarned(player, badgeId) then
		return true
	end
	
	-- 拉取成就配置并确认可发放
	local success, badgeInfo = pcall(function()
		return BadgeService:GetBadgeInfoAsync(badgeId)
	end)

	if success then
		if badgeInfo.IsEnabled then
			local awardSuccess, result = pcall(function()
				return BadgeService:AwardBadgeAsync(player.UserId, badgeId)
			end)

			if not awardSuccess then
				local err = tostring(result)
				if string.find(err, "badgeId is invalid or does not exist", 1, true) then
					-- 发放阶段识别到无效 id 同样熔断
					invalidBadgeIdCache[badgeId] = true
					warn("成就 id 无效，已停止重试", badgeId)
				else
					warn("发放成就失败", err, badgeId)
				end
			elseif not result then
				warn("成就未发放", badgeId)
			else
				return true
			end
		end
	else
		local err = tostring(badgeInfo)
		if string.find(err, "badgeId is invalid or does not exist", 1, true) then
			-- 拉取元信息失败且确认为无效 id，缓存后不再重复请求
			invalidBadgeIdCache[badgeId] = true
			warn("成就 id 无效，已停止重试", badgeId)
		else
			warn("拉取成就信息失败: " .. err, badgeId)
		end
	end
	return false
end

function BadgeUtility.awardBadgeByKey(player: Player, badgeKey: string)
	if BadgeKeys[badgeKey] ~= badgeKey then
		warn("未知的成就 key", badgeKey)
		return
	end

	if hasClaimedInSave(player, badgeKey) then
		return
	end

	local badgeId = resolveBadgeIdByKey(badgeKey)
	if not badgeId then
		warn("成就 key 未配置有效 id", badgeKey)
		return
	end

	if BadgeUtility.awardBadge(player, badgeId) then
		markClaimedInSave(player, badgeKey)
	end
end



return BadgeUtility