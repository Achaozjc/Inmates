--!strict

local copyDeep = require(script.Parent.copyDeep)

--[=[
	@function reconcile
	@within Dictionary

	Performs a one-way sync on the `source` table against the
	`template` table. Any keys found in `template` that are
	not found in `source` will be added to `source`.
]=]
local function reconcile<S, T>(src: S, template: T): S & T
	local tbl = table.clone(src :: any)

	for k, v in pairs(template :: any) do
		local sv = (src :: any)[k]
		if sv == nil then
			if type(v) == "table" then
				tbl[k] = copyDeep(v)
			else
				tbl[k] = v
			end
		elseif type(sv) == "table" then
			if type(v) == "table" then
				tbl[k] = reconcile(sv, v)
			else
				tbl[k] = copyDeep(sv)
			end
		end
	end

	return tbl :: any
end

return reconcile
