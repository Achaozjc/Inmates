local MarketplaceService = game:GetService("MarketplaceService")


local function getGamepassInfo(gamepassId: number)
	local success, productInfo = pcall(function()
		return MarketplaceService:GetProductInfoAsync(gamepassId, Enum.InfoType.GamePass) 
	end)
	if not success then
		warn("gamepass loaded error")
		return nil
	end
	return productInfo
end

return getGamepassInfo
