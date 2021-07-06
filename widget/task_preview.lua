--
-- Provides:
-- bling::task_preview::update   -- first line is the signal
--      t   (task)               -- indented lines are function parameters
-- bling::task_preview::visibility
--      s   (screen)
--      v   (boolean)
--
local wibox = require("wibox")
local helpers = require(tostring(...):match(".*bling") .. ".helpers")
local gears = require("gears")
local beautiful = require("beautiful")
local dpi = beautiful.xresources.apply_dpi

local function draw_widget(c, task_preview_box, screen_radius, client_radius,
                           client_opacity, client_bg, client_border_color,
                           client_border_width, widget_bg, widget_border_color,
                           widget_border_width, margin)

    task_preview_box:setup{
        {
            {
                {
                    {markup = c.name, widget = wibox.widget.textbox},
                    layout = wibox.layout.align.horizontal
                },
                layout = wibox.layout.align.vertical

            },
            margins = margin,
            widget = wibox.container.margin

        },
        bg = widget_bg,
        border_width = widget_border_width,
        border_color = widget_border_color,
        shape = helpers.shape.rrect(screen_radius),
        widget = wibox.container.background
    }
end

local enable = function(opts)
    local widget_x = dpi(20)
    local widget_y = dpi(20)
    local margin = beautiful.task_preview_widget_margin or dpi(0)
    local screen_radius = beautiful.task_preview_widget_border_radius or dpi(0)
    local client_radius = beautiful.task_preview_client_border_radius or dpi(0)
    local client_opacity = beautiful.task_preview_client_opacity or 0.5
    local client_bg = beautiful.task_preview_client_bg or "#000000"
    local client_border_color = beautiful.task_preview_client_border_color or
                                    "#ffffff"
    local client_border_width = beautiful.task_preview_client_border_width or
                                    dpi(3)
    local widget_bg = beautiful.task_preview_widget_bg or "#000000"
    local widget_border_color = beautiful.task_preview_widget_border_color or
                                    "#ffffff"
    local widget_border_width = beautiful.task_preview_widget_border_width or
                                    dpi(3)
    local placement_fn = nil

    if opts then
        widget_x = opts.x or widget_x
        widget_y = opts.y or widget_y
        placement_fn = opts.placement_fn or nil
    end

    local task_preview_box = wibox({
        type = "dropdown_menu",
        visible = false,
        ontop = true,
        input_passthrough = true,
        width = 200,
        height = 200,
        bg = "#00000000"
    })

    awesome.connect_signal("bling::task_preview::visibility", function(s, v, c)

        draw_widget(c, task_preview_box, screen_radius, client_radius,
                    client_opacity, client_bg, client_border_color,
                    client_border_width, widget_bg, widget_border_color,
                    widget_border_width, margin)

        if placement_fn then
            placement_fn(task_preview_box)
        else
            task_preview_box.x = s.geometry.x + widget_x
            task_preview_box.y = s.geometry.y + widget_y
        end

        task_preview_box.visible = v
    end)
end

return {enable = enable}
