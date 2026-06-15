--!strict

local HttpService = game:GetService("HttpService")

local function getItemsFitting<T>(container: { T }, items: { T }, maxLength: number): { T }
	local containerWithItems = table.clone(container)
	table.move(items, 1, #items, #containerWithItems + 1, containerWithItems)
	local min = string.len(HttpService:JSONEncode(container))
	local max = string.len(HttpService:JSONEncode(containerWithItems))
	local itemLength = math.ceil((max - min) / #items)

	if max <= maxLength then
		return items
	end

	local size = min
	local amount = 0
	while size + itemLength <= maxLength do
		size += itemLength
		amount += 1
	end

	if amount == 0 then
		return {}
	end

	return table.move(items, 1, amount, 1, {})
end

return getItemsFitting
