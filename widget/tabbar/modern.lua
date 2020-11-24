local gears = require("gears")
local wibox = require("wibox")
local beautiful = require("beautiful")
local xresources = require("beautiful.xresources")
local dpi = xresources.apply_dpi
local helpers = require(tostring(...):match(".*bling") .. ".module.helpers")

local bg_normal = beautiful.tabbar_bg_normal or beautiful.bg_normal or "#ffffff"
local fg_normal = beautiful.tabbar_fg_normal or beautiful.fg_normal or "#000000"
local bg_focus = beautiful.tabbar_bg_focus or beautiful.bg_focus or "#000000"
local fg_focus = beautiful.tabbar_fg_focus or beautiful.fg_focus or "#ffffff"
local font = beautiful.tabbar_font or beautiful.font or "Hack 15"
local size = beautiful.tabbar_size or dpi(40)
local border_radius =
    beautiful.mstab_border_radius or beautiful.border_radius or 6
local position = beautiful.tabbar_orientation or "top"
local close_color = beautiful.tabbar_color_close or beautiful.xcolor1 or
                        "#f9929b"
local min_color = beautiful.tabbar_color_min or beautiful.xcolor3 or "#fbdf90"
local float_color = beautiful.tabbar_color_float or beautiful.xcolor5 or
                        "#ccaced"

-- Helper to create buttons
local function create_title_button(c, color_focus, color_unfocus)
    local tb_color = wibox.widget {
        forced_width = dpi(8),
        forced_height = dpi(8),
        bg = color_focus,
        shape = gears.shape.circle,
        widget = wibox.container.background
    }

    local tb = wibox.widget {
        tb_color,
        width = dpi(25),
        height = dpi(20),
        strategy = "min",
        layout = wibox.layout.constraint
    }

    local function update()
        if client.focus == c then
            tb_color.bg = color_focus
        else
            tb_color.bg = color_unfocus
        end
    end
    update()
    c:connect_signal("focus", update)
    c:connect_signal("unfocus", update)

    tb.visible = true
    return tb
end

local function create(c, focused_bool, buttons)
    -- local flexlist = wibox.layout.flex.horizontal()
    local title_temp = c.name or c.class or "-"
    local bg_temp = bg_normal
    local fg_temp = fg_normal
    if focused_bool then
        bg_temp = bg_focus
        fg_temp = fg_focus
    end
    local text_temp = wibox.widget.textbox()
    text_temp.align = "center"
    text_temp.valign = "center"
    text_temp.font = font
    text_temp.markup = "<span foreground='" .. fg_temp .. "'>" .. title_temp ..
                           "</span>"
    c:connect_signal("property::name", function(_)
        local title_temp = c.name or c.class or "-"
        text_temp.markup =
            "<span foreground='" .. fg_temp .. "'>" .. title_temp .. "</span>"
    end)

    local tab_content = text_temp

    local close = create_title_button(c, close_color, bg_normal)
    close:connect_signal("button::press", function() c:kill() end)

    local floating = create_title_button(c, float_color, bg_normal)
    floating:connect_signal("button::press",
                            function() c.floating = not c.floating end)

    local min = create_title_button(c, min_color, bg_normal)
    min:connect_signal("button::press", function() c.minimized = true end)

    if focused_bool then
        tab_content = wibox.widget {
            {
                {close, floating, min, layout = wibox.layout.fixed.horizontal},
                margins = dpi(10),
                widget = wibox.container.margin
            },
            text_temp,
            nil,
            expand = "none",
            layout = wibox.layout.align.horizontal
        }
    end

    local wid_temp = wibox.widget({
        buttons = buttons,
        {
            tab_content,
            bg = bg_temp,
            shape = helpers.prrect(border_radius, true, true, false, false),
            widget = wibox.container.background
        },
        top = dpi(8),
        left = dpi(4),
        right = dpi(4),
        bottom = dpi(0),
        widget = wibox.container.margin
    })
    return wid_temp
end

return {
    layout = wibox.layout.flex.horizontal,
    create = create,
    position = "top",
    size = size,
    bg_normal = bg_normal,
    bg_focus = bg_focus
}
