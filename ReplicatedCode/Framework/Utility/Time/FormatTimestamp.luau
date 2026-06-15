--!strict

local formatTimestamp = {}

function formatTimestamp.second(sec:number)
	if sec > 86400 then
		return ('%id %02i:%02i:%02i'):format(sec / 86400, sec / 60^2 % 24,sec / 60 % 60,sec % 60)
	end
	if sec >= 3600 then
		return ('%02i:%02i:%02i'):format(sec / 60^2 % 24,sec / 60 % 60,sec % 60)
	end	
	return ('%02i:%02i'):format(sec / 60 % 60,sec % 60)
end


function formatTimestamp.minute(sec :number)
	return ('%id-%ih-%im'):format(sec / 86400,sec / 60^2 % 24,sec / 60 % 60)
end


function formatTimestamp.timeAgo(timestamp :number)
	local now = os.time() -- 当前时间戳
	local diff = now - timestamp -- 时间差，单位为秒
	local days = math.floor(diff / (24 * 60 * 60)) -- 转换为天数
	if days >= 30 then
		local months = math.floor(days / 30)
		return months.." months ago"
	elseif days >= 1 then
		return days.." days ago"
	else
		local hours = math.floor(diff / (60 * 60))	
		if hours >= 1 then
			return hours.." hours ago"
		else
			local min = math.floor(diff / 60)
			return min.." mins ago"
		end

	end
end



return formatTimestamp
