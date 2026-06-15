-- Disconnect and clear a table of connections
local function disconnectAndClear(tbl: {})
	for _, connection in tbl do
		connection:Disconnect()
	end
	table.clear(tbl)
end

return disconnectAndClear
