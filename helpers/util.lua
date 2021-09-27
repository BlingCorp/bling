-- TODO: This is definatley in the wrong place.
local beautiful = require("beautiful")
local gears = require("gears")
local M = {}

function M.retrieveArguments(original, fromArgs)
	local fromTheme = {}
	-- TODO: make this into one table?
	local moduleName = original[1]

	if not moduleName then
		error("No module name given, is required...")
	end

	local ignoreFromTheme = original[2] or {}
	fromArgs = fromArgs or {}

	-- This is for some of my things that dont use the whole prefix thing,
	-- instead they just use a table
	-- TODO: Skip collection from beautiful for certain things as it might become a bit of a mess
	if type(beautiful[moduleName]) == "table" then
		fromTheme = beautiful[moduleName]
		goto skipThemeCollection
	end

	for key, _ in pairs(original) do
		if gears.table.hasitem(ignoreFromTheme, key) ~= nil then
			goto continue
		end
		fromTheme[key] = beautiful[moduleName .. "_" .. key] 
		::continue::
	end

	::skipThemeCollection::

	-- Importance: Args > Theme > Default
	return gears.table.crush(original, gears.table.crush(fromTheme, fromArgs))
end

return M
