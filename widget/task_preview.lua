--
-- Provides:
-- bling::task_preview::visibility
--      s   (screen)
--      v   (boolean)
--      c   (client)
--
local wibox = require("wibox")
local helpers = require(tostring(...):match(".*bling") .. ".helpers")
local gears = require("gears")
local beautiful = require("beautiful")
local dpi = beautiful.xresources.apply_dpi
local cairo = require("lgi").cairo

local function draw_widget(c, task_preview_box, screen_radius, widget_bg,
                           widget_border_color, widget_border_width, margin)

    local content = gears.surface(c.content)
    local cr = cairo.Context(content)
    local x, y, w, h = cr:clip_extents()
    local img = cairo.ImageSurface.create(cairo.Format.ARGB32, w - x, h - y)
    cr = cairo.Context(img)
    cr:set_source_surface(content, 0, 0)
    cr.operator = cairo.Operator.SOURCE
    cr:paint()

    task_preview_box:setup{
        {
            {
                {
                    {
                        image = gears.surface.load(c.icon),
                        resize = true,
                        forced_height = dpi(20),
                        forced_width = dpi(20),
                        widget = wibox.widget.imagebox
                    },
                    {
                        {
                            markup = c.name,
                            align = "center",
                            widget = wibox.widget.textbox
                        },
                        left = dpi(4),
                        right = dpi(4),
                        widget = wibox.container.margin
                    },
                    layout = wibox.layout.align.horizontal
                },
                {
                    {
                        {
                            image = gears.surface.load(img),
                            resize = true,
                            widget = wibox.widget.imagebox
                        },
                        valign = "center",
                        halign = "center",
                        widget = wibox.container.place
                    },
                    top = margin * 0.25,
                    widget = wibox.container.margin
                },
                fill_space = true,
                layout = wibox.layout.fixed.vertical
            },
            margins = margin,
            widget = wibox.container.margin
        },
        bg = widget_bg,
        shape_border_width = widget_border_width,
        shape_border_color = widget_border_color,
        shape = helpers.shape.rrect(screen_radius),
        widget = wibox.container.background
    }
end

local enable = function(opts)

    local opts = opts or {}

    local widget_x = opts.x or dpi(20)
    local widget_y = opts.y or dpi(20)
    local widget_height = opts.height or dpi(200)
    local widget_width = opts.width or dpi(200)
    local placement_fn = opts.placement_fn or nil

    local margin = beautiful.task_preview_widget_margin or dpi(0)
    local screen_radius = beautiful.task_preview_widget_border_radius or dpi(0)
    local widget_bg = beautiful.task_preview_widget_bg or "#000000"
    local widget_border_color = beautiful.task_preview_widget_border_color or
                                    "#ffffff"
    local widget_border_width = beautiful.task_preview_widget_border_width or
                                    dpi(3)

    local task_preview_box = wibox({
        type = "dropdown_menu",
        visible = false,
        ontop = true,
        input_passthrough = true,
        width = widget_width,
        height = widget_height,
        bg = "#00000000"
    })

    awesome.connect_signal("bling::task_preview::visibility", function(s, v, c)
        draw_widget(c, task_preview_box, screen_radius, widget_bg,
                    widget_border_color, widget_border_width, margin)

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
