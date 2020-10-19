local beautiful = require("beautiful")

local mstab = require("bling.layout.mstab")
beautiful.layout_mstab = mstab.get_icon()

local vertical = require("bling.layout.vertical")
beautiful.layout_vertical = vertical.get_icon()

local horizontal = require("bling.layout.horizontal")
beautiful.layout_horizontal = horizontal.get_icon()

local centered = require("bling.layout.centered")
beautiful.layout_centered = centered.get_icon()

local layout = {
    mstab = mstab.layout,
    centered = centered.layout,
    vertical = vertical.layout,
    horizontal = horizontal.layout
}

return layout
