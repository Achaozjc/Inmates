local rand = Random.new()



local function getProbability(percent :number)
	return rand:NextInteger(1,10000) < percent * 10000
end

return getProbability
