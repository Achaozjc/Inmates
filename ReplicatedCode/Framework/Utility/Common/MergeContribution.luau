local function mergeContribution(data, contrib)
	if not contrib then return end
	for k, v in pairs(contrib) do
		data[k] = (data[k] or 0) + v
	end
end

return mergeContribution
