local awful = require("awful")
local wibox = require("wibox")
local helpers = require(tostring(...):match(".*bling") .. ".helpers")
local gears = require("gears")
local beautiful = require("beautiful")
local dpi = beautiful.xresources.apply_dpi
local cairo = require("lgi").cairo

local function draw_widget(tag_preview_box, t, tag_preview_image, scale,
                           prev_screen_width, prev_screen_height, screen_radius,
                           client_radius, client_opacity, client_bg,
                           client_border_color, client_border_width, widget_bg,
                           widget_border_color, widget_border_width)

    local client_list = wibox.layout.manual()
    client_list.forced_height = prev_screen_height
    client_list.forced_width = prev_screen_width
    for i, c in ipairs(t:clients()) do

        local img_box = wibox.widget {
            image = gears.surface.load(c.icon),
            resize = true,
            forced_height = 100 * scale,
            forced_width = 100 * scale,
            widget = wibox.widget.imagebox
        }

        if tag_preview_image then
            if c.prev_content or t.selected then
                local content
                if t.selected then
                    content = gears.surface(c.content)
                else
                    content = gears.surface(c.prev_content)
                end
                local cr = cairo.Context(content)
                local x, y, w, h = cr:clip_extents()
                local img = cairo.ImageSurface.create(cairo.Format.ARGB32,
                                                      w - x, h - y)
                cr = cairo.Context(img)
                cr:set_source_surface(content, 0, 0)
                cr.operator = cairo.Operator.SOURCE
                cr:paint()

                img_box = wibox.widget {
                    image = gears.surface.load(img),
                    resize = true,
                    opacity = client_opacity,
                    forced_height = math.floor(c.height * scale),
                    forced_width = math.floor(c.width * scale),
                    widget = wibox.widget.imagebox
                }
            end
        end

        local client_box = wibox.widget {
            {
                nil,
                {
                    nil,
                    img_box,
                    nil,
                    expand = "outside",
                    layout = wibox.layout.align.horizontal
                },
                nil,
                expand = "outside",
                widget = wibox.layout.align.vertical
            },
            forced_height = math.floor(c.height * scale),
            forced_width = math.floor(c.width * scale),
            bg = client_bg,
            border_color = client_border_color,
            border_width = client_border_width,
            shape = helpers.shape.rrect(client_radius),
            widget = wibox.container.background
        }

        client_box.point = {
            x = math.floor(c.x * scale),
            y = math.floor(c.y * scale)
        }

        client_list:add(client_box)

    end

    tag_preview_box:setup{
        {
            {
                {
                    client_list,
                    forced_height = prev_screen_height,
                    forced_width = prev_screen_width,
                    bg = widget_bg,
                    widget = wibox.container.background
                },
                layout = wibox.layout.align.horizontal
            },
            layout = wibox.layout.align.vertical
        },
        bg = widget_bg,
        border_width = widget_border_width,
        border_color = widget_border_color,
        shape = helpers.shape.rrect(screen_radius),
        widget = wibox.container.background
    }
end

local enable = function(opts)
    local tag_preview_image = false
    local widget_x = dpi(20)
    local widget_y = dpi(20)
    local screen_radius = beautiful.tag_preview_widget_border_radius or dpi(0)
    local client_radius = beautiful.tag_preview_client_border_radius or dpi(0)
    local client_opacity = beautiful.tag_preview_client_opacity or 0.5
    local client_bg = beautiful.tag_preview_client_bg or "#000000"
    local client_border_color = beautiful.tag_preview_client_border_color or
                                    "#ffffff"
    local client_border_width = beautiful.tag_preview_client_border_width or
                                    dpi(3)
    local widget_bg = beautiful.tag_preview_widget_bg or "#000000"
    local widget_border_color = beautiful.tag_preview_widget_border_color or
                                    "#ffffff"
    local widget_border_width = beautiful.tag_preview_widget_border_width or
                                    dpi(3)

    local scale = 0.2

    if opts then
        tag_preview_image = opts.show_client_content or tag_preview_image
        widget_x = opts.x or widget_x
        widget_y = opts.y or widget_y
        scale = opts.scale or scale
    end

    local prev_screen_width = math.floor(
                                  awful.screen.focused().geometry.width * scale)
    local prev_screen_height = math.floor(
                                   awful.screen.focused().geometry.height *
                                       scale)

    local tag_preview_box = wibox({
        visible = false,
        ontop = true,
        width = prev_screen_width,
        height = prev_screen_height,
        input_passthrough = true,
        bg = "#00000000",
        x = widget_x,
        y = widget_y
    })

    tag.connect_signal("property::selected", function(t)
        for _, c in ipairs(t:clients()) do
            c.prev_content = gears.surface.duplicate_surface(c.content)
        end
    end)

    awesome.connect_signal("bling::tag_preview::update", function(t)
        draw_widget(tag_preview_box, t, tag_preview_image, scale,
                    prev_screen_width, prev_screen_height, screen_radius,
                    client_radius, client_opacity, client_bg,
                    client_border_color, client_border_width, widget_bg,
                    widget_border_color, widget_border_width)
    end)

    awesome.connect_signal("bling::tag_preview::visibility", function(s, v)
        tag_preview_box.screen = s
        tag_preview_box.visible = v
    end)
end

return {enable = enable}
