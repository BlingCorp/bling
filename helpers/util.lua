-- TODO: This is definatley in the wrong place.
local beautiful = require("beautiful")
local gears = require("gears")
local M = {}

--[[ Example
function (args)
  local helpers = require(tostring(...):match(".*bling") .. ".helpers")
  local options = helpers.util.retrieveArguments({
  	"<Module Name>"
  	{ "other" },
  	color = "#fff",
  	other = "aaa"
  }, args)
  end
]]--


-- [TODO] Allow certain arguments to be generated within the context of other arguments
-- [TODO] Type check arguments as much as possible
-- [TODO] Allow `ignoreFromTheme' to be a pattern
function M.retrieveArguments(original, fromArgs)
	local fromTheme = {}
	-- [TODO] make this into one table?
	local moduleName = original[1]

	if not moduleName then
		error("No module name given, is required...")
	end

	local ignoreFromTheme = original[2] or {}
	fromArgs = fromArgs or {}

	-- This is for some of my things that dont use the whole prefix thing,
	-- instead they just use a table
	-- [TODO]: Skip collection from beautiful for certain things as it might become a bit of a mess
	if type(beautiful[moduleName]) == "table" then
		fromTheme = beautiful[moduleName]
	else

	local to_be_ignored = function(it)
	  return gears.table.hasitem(ignoreFromTheme, it) ~= nil
	end
	if (type(ignoreFromTheme) == "string") then
	  to_be_ignored = function(it) return string.find(it, ignoreFromTheme) ~= nil end
	end
	
	for key, _ in pairs(original) do
	  if to_be_ignored(key) then
			goto continue
		end
		fromTheme[key] = beautiful[moduleName .. "_" .. key] 
		::continue::
	end

	end
	
	-- Importance: Args > Theme > Default
	return gears.table.crush(original, gears.table.crush(fromTheme, fromArgs))
end

return M
