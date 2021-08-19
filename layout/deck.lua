local awful = require("awful")
local gears = require("gears")
local gcolor = require("gears.color")
local beautiful = require("beautiful")

local mylayout = {}

mylayout.name = "deck"

function mylayout.arrange(p)
    local area = p.workarea
    local t = p.tag or screen[p.screen].selected_tag
    local client_count = #p.clients

    if client_count == 1 then
        local c = p.clients[1]
        local g = {
            x = area.x,
            y = area.y,
            width = area.width,
            height = area.height,
        }
        p.geometries[c] = g
        return
    end

    local xoffset = area.width * 0.1 / (client_count - 1)
    local yoffset = area.height  * 0.1 / (client_count - 1)

    for idx=1,client_count do
        local c = p.clients[idx]
        local g = {
            x = area.x + (idx - 1) * xoffset,
            y = area.y + (idx - 1) * yoffset,
            width = area.width - (xoffset * (client_count - 1)),
            height = area.height - (yoffset * (client_count - 1)),
        }
        p.geometries[c] = g
    end
end

local icon_raw = gears.filesystem.get_configuration_dir() .. tostring(...):match("^.*bling"):gsub("%.", "/") .. "/icons/layouts/deck.png"

local function get_icon()
    if icon_raw ~= nil then
        return gcolor.recolor_image(icon_raw, beautiful.fg_normal)
    else
        return nil
    end
end

return {
    layout = mylayout,
    icon_raw = icon_raw,
    get_icon = get_icon,
}
