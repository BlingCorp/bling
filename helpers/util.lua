-- TODO: This is definatley in the wrong place.
local beautiful = require("beautiful")
local gears = require("gears")
local M = {}

function M.retrieveArguments(original, fromArgs)
	local fromTheme = {}
	local moduleName = original[1]
	fromArgs = fromArgs or {}

	-- This is for some of my things that dont use the whole prefix thing,
	-- instead they just use a table
	if type(beautiful[moduleName]) == "table" then
		fromTheme = beautiful[moduleName]
		goto skipThemeCollection
	end

	for key, _ in pairs(original) do
		fromTheme[key] = beautiful[moduleName .. "_" .. key] 
	end

	::skipThemeCollection::

	return gears.table.crush(original, gears.table.crush(fromTheme, fromArgs))
end

return M
