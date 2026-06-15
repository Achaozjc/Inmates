local Players = game:GetService("Players")

-- player : 进入或离开服务器的玩家
-- bool : 指player进入时还是离开时
-- plr : 服务器内的其他玩家
local function updateFriendCount(player:Player,bool:boolean) 
	
	local allPlayersInServer = Players:GetPlayers() -- 服务器里所有玩家
	for _,plr in ipairs(allPlayersInServer) do
		if plr == player then continue end
		if bool then
			if player:IsFriendsWithAsync(plr.UserId) then
				local oldValue = player:GetAttribute("FriendCount") or 0
				oldValue =  oldValue + 1
				player:SetAttribute("FriendCount",oldValue)
			end
		end

		if plr:IsFriendsWithAsync(player.UserId) then
			local oldValue = plr:GetAttribute("FriendCount") or 0
			oldValue = bool and oldValue + 1 or oldValue - 1
			plr:SetAttribute("FriendCount",oldValue)
		end
	end

end

return updateFriendCount