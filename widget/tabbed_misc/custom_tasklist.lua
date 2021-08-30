local wibox = require("wibox")
local awful = require("awful")
local gears = require("gears")
local beautiful = require("beautiful")
local dpi = require("beautiful.xresources").apply_dpi

local function tabobj_support(self, c, index, clients)
	-- Self is the background widget in this context
	if not c.bling_tabbed then
		return
	end

	local group = c.bling_tabbed

	-- Single item tabbed group's dont get special rendering
	if #group.clients > 1 then
		local wrapper = wibox.widget({
			{
				-- This is so dumb... but it works so meh
				{
					id = "row1",
					layout = wibox.layout.flex.horizontal,
				},
				{
					id = "row2",
					layout = wibox.layout.flex.horizontal,
				},
				spacing = dpi(2),
				layout = wibox.layout.fixed.vertical,
			},
			id = "click_role",
			widget = wibox.container.margin,
			margins = dpi(5),
		})

		for idx, c in ipairs(group.clients) do
			if c and c.icon then
				-- TODO: Don't do this in a -1iq way
				local row_no = 'row1'
				if idx > 2 then
					row_no = 'row2'
				end
				wrapper:get_children_by_id(row_no)[1]:add(wibox.widget {
					{
						widget = awful.widget.clienticon,
						client = c
					},
					widget = wibox.container.constraint,
					width = 24,
					height = 24
				})
			end
		end

		self.widget = wrapper
	end
end

return tabobj_support
