local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")


local function checkFriend(plr:Player)
	if not (plr and plr:IsDescendantOf(Players)) then
		return 0
	end
	
	local friendCount = plr:GetAttribute("FriendCount") or 0
	print("friendCount",friendCount)
	
	return friendCount 

end

return checkFriend