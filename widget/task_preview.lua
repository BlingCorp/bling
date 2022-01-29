--
-- Provides:
-- bling::task_preview::visibility
--      s   (screen)
--      v   (boolean)
--      c   (client)
--
local awful = require("awful")
local wibox = require("wibox")
local helpers = require(tostring(...):match(".*bling") .. ".helpers")
local gears = require("gears")
local beautiful = require("beautiful")
local dpi = beautiful.xresources.apply_dpi
local cairo = require("lgi").cairo

-- TODO: rename structure to something better?
local function draw_widget(
    c,
    opts)
  
    if not pcall(function()
        return type(c.content)
    end) then
        return
    end
    local content = gears.surface(c.content)
    local cr = cairo.Context(content)
    local x, y, w, h = cr:clip_extents()
    local img = cairo.ImageSurface.create(cairo.Format.ARGB32, w - x, h - y)
    cr = cairo.Context(img)
    cr:set_source_surface(content, 0, 0)
    cr.operator = cairo.Operator.SOURCE
    cr:paint()

    local widget = wibox.widget({
        (opts.widget_template or {
            {
                {
                    {
                        {
                            id = "icon_role",
                            resize = true,
                            forced_height = dpi(20),
                            forced_width = dpi(20),
                            widget = wibox.widget.imagebox,
                        },
                        {
                            {
                                id = "name_role",
                                align = "center",
                                widget = wibox.widget.textbox,
                            },
                            left = dpi(4),
                            right = dpi(4),
                            widget = wibox.container.margin,
                        },
                        layout = wibox.layout.align.horizontal,
                    },
                    {
                        {
                            {
                                id = "image_role",
                                resize = true,
                                clip_shape = helpers.shape.rrect(opts.widget_border_radius),
                                widget = wibox.widget.imagebox,
                            },
                            valign = "center",
                            halign = "center",
                            widget = wibox.container.place,
                        },
                        top = opts.margin * 0.25,
                        widget = wibox.container.margin,
                    },
                    fill_space = true,
                    layout = wibox.layout.fixed.vertical,
                },
                margins = opts.margin,
                widget = wibox.container.margin,
            },
            bg = opts.widget_bg,
            shape_border_width = opts.widget_border_width,
            shape_border_color = opts.widget_border_color,
            shape = helpers.shape.rrect(opts.widget_border_radius),
            widget = wibox.container.background,
        }),
        width = opts.widget_width,
        height = opts.widget_height,
        widget = wibox.container.constraint,
    })

    -- TODO: have something like a create callback here?

    for _, w in ipairs(widget:get_children_by_id("image_role")) do
        w.image = img -- TODO: copy it with gears.surface.xxx or something
    end

    for _, w in ipairs(widget:get_children_by_id("name_role")) do
        w.text = c.name
    end

    for _, w in ipairs(widget:get_children_by_id("icon_role")) do
        w.image = c.icon -- TODO: detect clienticon
    end

    return widget
end

local enable = function(opts)
    local opts = helpers.util.retrieveArguments({
		"task_preview",
		{ "x" , "y", "height", "width", "placement_fn" },
		x = dpi(20),
		y = dpi(20),
		height = dpi(200),
		width = dpi(200),
		margin = dpi(1),
		
		placement_fn = nil,
		widget_margin = dpi(0),
		widget_border_radius = dpi(0),
		widget_bg = "#000000",
		widget_border_color = "#ffffff",
		widget_border_width = dpi(3)
}, opts)

    local task_preview_box = awful.popup({
        type = "dropdown_menu",
        visible = false,
        ontop = true,
        placement = opts.placement_fn,
        widget = wibox.container.background, -- A dummy widget to make awful.popup not scream
        input_passthrough = true,
        bg = "#00000000",
    })

    awesome.connect_signal("bling::task_preview::visibility", function(s, v, c)
        if v then
            -- Update task preview contents
            task_preview_box.widget = draw_widget(
                c,
                opts
            )
        end

        if not placement_fn then
            task_preview_box.x = s.geometry.x + opts.x
            task_preview_box.y = s.geometry.y + opts.y
        end

        task_preview_box.visible = v
    end)
end

return { enable = enable, draw_widget = draw_widget}
