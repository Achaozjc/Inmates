local placeId = game.PlaceId

local mainPlaceId = {
	108384212346935,
}
--是否是主图
local isLobby : boolean = (table.find(mainPlaceId, placeId) ~= nil)

return {
	Lobby = isLobby and 108384212346935 or 108384212346935,
}
