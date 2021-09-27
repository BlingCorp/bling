--
-- Provides:
-- bling::tag_preview::update   -- first line is the signal
--      t   (tag)               -- indented lines are function parameters
-- bling::tag_preview::visibility
--      s   (screen)
--      v   (boolean)
--
local awful = require("awful")
local wibox = require("wibox")
local helpers = require(tostring(...):match(".*bling") .. ".helpers")
local gears = require("gears")
local beautiful = require("beautiful")
local dpi = beautiful.xresources.apply_dpi
local cairo = require("lgi").cairo


local function draw_widget(t, o, geo)

		local client_list = wibox.layout.manual()
		client_list.forced_height = geo.height
		client_list.forced_width = geo.width
		local tag_screen = t.screen
		for i, c in ipairs(t:clients()) do
			if not c.hidden and not c.minimized then
				local img_box = wibox.widget({
					image = gears.surface.load(c.icon),
					resize = true,
					forced_height = 100 * o.scale,
					forced_width = 100 * o.scale,
					widget = wibox.widget.imagebox
				})

				-- If fails to set image, fallback to a awesome icon
				if not pcall(function() img_box.image = gears.surface.load(c.icon) end) then
				img_box.image = beautiful.theme_assets.awesome_icon (24, "#222222", "#fafafa")
			end

			if o.show_client_content then
				if c.prev_content or t.selected then
					local content
					if t.selected then
						content = gears.surface(c.content)
					else
						content = gears.surface(c.prev_content)
					end
					local cr = cairo.Context(content)
					local x, y, w, h = cr:clip_extents()
					local img = cairo.ImageSurface.create(
					cairo.Format.ARGB32,
					w - x,
					h - y
					)
					cr = cairo.Context(img)
					cr:set_source_surface(content, 0, 0)
					cr.operator = cairo.Operator.SOURCE
					cr:paint()

					img_box = wibox.widget({
						image = gears.surface.load(img),
						resize = true,
						opacity = o.client_opacity,
						forced_height = math.floor(c.height * o.scale),
						forced_width = math.floor(c.width * o.scale),
						widget = wibox.widget.imagebox
					})
				end
			end

			local client_box = wibox.widget({
				{
					nil,
					{
						nil,
						img_box,
						nil,
						expand = "outside",
						layout = wibox.layout.align.horizontal,
					},
					nil,
					expand = "outside",
					widget = wibox.layout.align.vertical,
				},
				forced_height = math.floor(c.height * o.scale),
				forced_width = math.floor(c.width * o.scale),
				bg = o.client_bg,
				shape_border_color = o.client_border_color,
				shape_border_width = o.client_border_width,
				shape = helpers.shape.rrect(o.client_border_radius),
				widget = wibox.container.background
			})

			client_box.point = {
				x = math.floor((c.x - geo.x) * o.scale),
				y = math.floor((c.y - geo.y) * o.scale)
			}

			client_list:add(client_box)
		end
	end

	return {
		{
			{
				{
					{
						client_list,
						forced_height = geo.height,
						forced_width = geo.width,
						widget = wibox.container.place,
					},
					layout = wibox.layout.align.horizontal,
				},
				layout = wibox.layout.align.vertical,
			},
			margins = o.widget_margin,
			widget = wibox.container.margin

		},
		bg = o.widget_bg,
		shape_border_width = o.widget_border_width,
		shape_border_color = o.widget_border_color,
		shape = helpers.shape.rrect(o.screen_border_radius),
		widget = wibox.container.background
	}
end

local enable = function(opts)


	-- TODO:
	-- For the backgrounds, somehow detect if they are a image!
	-- and use bgimage
	--
	-- NOTE: I think I might have changed some names here,
	-- If so I need to change them to fit the current api.
	opts = helpers.util.retrieveArguments({
		"tag_preview", -- Module name
		{ "show_client_content", "x", "y", "scale", "honor_workarea", "honor_padding", "placement_fn" }, -- ignore from theme
		show_client_content = false,
		x = dpi(20),
		y = dpi(20),
		scale = 0.2,
		honor_workarea = false,
		honor_padding = false,
		placement_fn = nil,

		widget_margin = dpi(0),
		widget_border_radius = dpi(0),
		client_border_radius = dpi(0),
		client_opacity = 0.5,
		client_bg = "#000000",
		client_border_color = "#ffffff",
		client_border_width = dpi(3),
		widget_bg = "#000000",
		widget_border_color = "#ffffff",
		widget_border_width = dpi(3)
	}, opts) 

	local tag_preview_box = awful.popup({
		type = "dropdown_menu",
		visible = false,
		ontop = true,
		placement = opts.placement_fn,
		widget = wibox.container.background,
		input_passthrough = true,
		bg = "#00000000",
	})

	tag.connect_signal("property::selected", function(t)
		for _, c in ipairs(t:clients()) do
			c.prev_content = gears.surface.duplicate_surface(c.content)
		end
	end)

	awesome.connect_signal("bling::tag_preview::update", function(t)
		local geo = t.screen:get_bounding_geometry{
			honor_padding = opts.honor_padding,
			honor_workarea = opts.honor_work_area
		}

		tag_preview_box.maximum_width = scale * geo.width + margin * 2
		tag_preview_box.maximum_height = scale * geo.height + margin * 2
		tag_preview_box:setup(draw_widget(tag, opts, margin))
	end)

	awesome.connect_signal("bling::tag_preview::visibility", function(s, v)
		if not placement_fn then
			tag_preview_box.x = s.geometry.x + opts.x
			tag_preview_box.y = s.geometry.y + opts.y
		end

		tag_preview_box.visible = v
	end)
end

return { enable = enable }
