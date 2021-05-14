local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local gcolor = require("gears.color")
local beautiful = require("beautiful")

local bg_normal    = beautiful.tabbar_bg_normal or beautiful.bg_normal or "#ffffff"
local fg_normal    = beautiful.tabbar_fg_normal or beautiful.fg_normal or "#000000"
local bg_focus     = beautiful.tabbar_bg_focus  or beautiful.bg_focus  or "#000000"
local fg_focus     = beautiful.tabbar_fg_focus  or beautiful.fg_focus  or "#ffffff"
local font         = beautiful.tabbar_font      or beautiful.font      or "Hack 15"
local size         = beautiful.tabbar_size      or 20
local position     = beautiful.tabbar_position  or "top"

local function get_title(c, fg)
    local name = c.name or c.class or "-"
    return "<span foreground='" .. fg .. "'>" .. name .. "</span>"
end

local function create(c, focused_bool, buttons)
    local bg_temp = focused_bool and bg_focus or bg_normal
    local fg_temp = focused_bool and fg_focus or fg_normal

    local text_temp  = wibox.widget.textbox()
    text_temp.align  = "center"
    text_temp.valign = "center"
    text_temp.font   = font
    text_temp.markup = get_title(c, fg_temp)

    c:connect_signal("property::name", function(cl)
        text_temp.markup = get_title(cl, fg_temp)
    end)

    c:connect_signal("unfocus", function(cl)
        text_temp.markup = get_title(cl, fg_temp)
    end)

    local wid_temp = wibox.widget({
        {
            { -- Left
                wibox.widget.base.make_widget(awful.titlebar.widget.iconwidget(c)),
                buttons = buttons,
                layout  = wibox.layout.fixed.horizontal,
            },
            { -- Middle
                { -- Title
                    id = "tab_name",
                    text_temp,
                    align  = "center",
                    widget = wibox.container.background(),
                },
                buttons = buttons,
                layout  = wibox.layout.flex.horizontal,
            },
            { -- Right
                wibox.widget.base.make_widget(awful.titlebar.widget.closebutton(c)),
                layout = wibox.layout.fixed.horizontal,
            },
            layout = wibox.layout.align.horizontal,
        },
        bg = bg_temp,
        fg = fg_temp,
        widget = wibox.container.background(),
        create_callback = function(self, c, index, objects) --luacheck: no unused args
            self:get_children_by_id('tab_name')[1].markup = get_title(c, fg_temp)
        end,
        update_callback = function(self, c, index, objects) --luacheck: no unused args
            self:get_children_by_id('tab_name')[1].markup = get_title(c, fg_temp)
            self:emit_signal('widget::redraw_needed')
        end,
    })

    return wid_temp
end


return {
    layout    = wibox.layout.flex.horizontal,
    create    = create,
    position  = position,
    size      = size,
    bg_normal = bg_normal,
    bg_focus  = bg_focus
}
