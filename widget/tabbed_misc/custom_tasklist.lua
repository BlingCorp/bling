
local wibox = require('wibox')
local awful = require('awful')
local gears = require('gears')
local beautiful = require('beautiful')
local dpi = require("beautiful.xresources").apply_dpi

-- Handle arguments and fallback: does gears.table.override do the same thing?
local function tbl_fallback(original, fallback)
	for key, value in pairs(fallback) do
		if original[key] == nil then
			orginial[key] = value
		end
	end
	return original
end

local function update_list(c, s, list, opts)
	if awful.widget.tasklist.filter.currenttags(c, s) and c ~= nil and c.icon ~= nil then -- Im not paranoid...
		widget = wibox.widget(opts.widget_template or {
			{
				{
					nil,
					{
						widget = awful.widget.clienticon,
						id = "client_icon",
						buttons = awful.button({}, 1, function() -- Definatley Cheating Here
							c:activate({ action = "toggle_minimization", context = "tasklist" })
						end),
					},
					nil,
					expand = "none",
					layout = wibox.layout.align.horizontal,
				},
				forced_width = opts.icon_size,
				forced_height = opts.icon_size,
				widget = wibox.container.margin,
			},
			top = dpi(8),
			bottom = dpi(8),
			widget = wibox.container.margin,
		})

		for _, w in ipairs(widget:get_children_by_id("client_icon")) do
			w.image = c.icon
			w.client = c 
		end

		for _, w in ipairs(widget:get_children_by_id("click_role")) do
			w:add_button(awful.button({}, 1, function()
				c:activate({ action = "toggle_minimization", context = "tasklist" })
			end))
		end

		list:add(widget)
	end
end

local function full_update_list(s, list, opts)
	-- Reset list
	list:reset()

	-- Get all windows and store detected groups
	local groups = {}
	for _, c in ipairs(awful.screen.focused().selected_tag:clients()) do
		if c.bling_tabbed and (not tbl_contains(groups, c.bling_tabbed)) then
			groups[#groups + 1] = c.bling_tabbed
		else
			update_list(c, s, list, opts)
		end
	end

	-- Loop over groups
	for _, group in ipairs(groups) do
	
		-- Remove the focused window from the titlebar: prevent duplication
		for index, child in ipairs(list.children) do
			local x = child:get_children_by_id("client_icon")
			if #x > 0 and x[1].client and tbl_contains(group.clients, x[1].client) then
				list:remove(index)
			end
		end

		-- Generate and add wrapper widget if > 1 children
		if #group.clients > 1 then

			local wrapper = wibox.widget({
				{
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
						spacing = opts.group_row_spacing,
						layout = wibox.layout.fixed.vertical,
					},
					halign = "center",
					valign = "center",
					id = 'click_role',
					widget = wibox.container.place,
				},
				widget = wibox.container.margin,
				margins = opts.group_margin
			})

			for _, w in ipairs(wrapper:get_children_by_id('click_role')) do
				w:add_button(awful.button({}, 1, function()
						group.clients[group.focused_idx]:activate()
					end))
			end

			for idx, c in ipairs(group.clients) do
				if c and c.icon then
					-- TODO: Don't do this in a -1iq way
					if idx <= 2 then
						wrapper:get_children_by_id("row1")[1]:add(opts.group_icon_fn(c))
					else
						wrapper:get_children_by_id("row2")[1]:add(opts.group_icon_fn(c))
					end
				end
			end

			list:add(wrapper)
		else
			update_list(group.clients[group.focused_idx], s, list)
		end
	end
end

-- Sorry about the pcalls but it only fails rarely... I think...
return function(s, opts)
	opts = tbl_fallback(gears.table.join(opts, beautiful.bling_tabbed_misc_tasklist), {
		group_margin = dpi(8),
		group_row_spacing = dpi(2),
		icon_size = dpi(24),
		group_icon_fn = awful.widget.clienticon
	})

	local list = wibox.widget({
		layout = opts.tasklist_layout or wibox.layout.fixed.vertical,
	})

	local update = function()
		pcall(function()
			full_update_list(s, list, opts)
		end)
	end 

	-- TODO: Be a bit more mindful of multiple screen systems
	-- Update on new
	client.connect_signal("request::manage", update)

	-- Update on destroy
	client.connect_signal("request::unmanage", update)

	-- Update on switching tag
	awful.tag.attached_connect_signal(s, "property::selected", update)

	-- Update on bling
	awesome.connect_signal("bling::tabbed::update", update)

	update()

	return list
end

