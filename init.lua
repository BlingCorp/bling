--[[
     Bling
     Layouts, widgets and utilities for Awesome WM
--]]
local before = ...
return setmetatable({}, {
    __index = function(_, key)
        return require(before .. "." .. key)
    end,
})
