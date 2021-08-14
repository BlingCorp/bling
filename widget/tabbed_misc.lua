local wibox = require('wibox')
local awful = require('awful')
local gears = require('gears')
local beautiful = require('beautiful')
local dpi = require("beautiful.xresources").apply_dpi
local module = {}

-- Just check if a table contains a value.
local function tbl_contains(tbl, item)
	for _, v in ipairs(tbl) do
		if v == item then
			return true
		end
	end
	return false
end

-- Needs to be run, every time a new titlbear is created
function module.titlebar_indicator(c)

	opts = (beautiful.bling_tabbed_misc and beautiful.bling_tabbed_misc.titlebar_indicator) or {}

	-- Container to store icons
	local tabbed_icons = wibox.widget({
		layout = wibox.layout.fixed.horizontal,
		spacing = opts.layout_spacing or dpi(4),
	})

	awesome.connect_signal("bling::tabbed::client_removed", function(removed_c)
		for idx, icon in ipairs(tabbed_icons.children) do
			if icon:get_children_by_id("icon_role")[1].client == removed_c then
				tabbed_icons:remove(idx)
			end
		end
	end)

	local function recreate(group)
		if tbl_contains(group.clients, c) then
			tabbed_icons:reset()
			local focused = group.clients[group.focused_idx]
		
			-- Autohide?
			if #group.clients == 1 then
				return
			end

			for idx, client in ipairs(group.clients) do
				local widget = wibox.widget(opts.widget_template or {
					{
						{
							{
								id = 'icon_role',
								forced_width = opts.icon_size or dpi(20),
								forced_height = opts.icon_size or dpi(20),
								widget = awful.widget.clienticon,
							},
							margins = opts.icon_margin or dpi(4),
							widget = wibox.container.margin,
						},
						bg = (client == focused and (opts.bg_color_focus or "#ff0000")) or (opts.bg_color or "#00000000"),
						shape = function(cr,w,h) gears.shape.rounded_rect(cr,w,h,5) end,
						id = 'click_role',
						widget = wibox.container.background,
					},
					halign = "center",
					valign = "center",
					widget = wibox.container.place,
				})

				-- Add icons & etc
				for _, w in ipairs(widget:get_children_by_id("icon_role")) do
					w.image = client.icon
					w.client = client
				end

				for _, w in ipairs(widget:get_children_by_id("click_role")) do
					w:add_button(awful.button({}, 1, function()
						bling.module.tabbed.switch_to(group,idx)
					end))
				end

				tabbed_icons:add(widget)
			end
		end
	end

	awesome.connect_signal("bling::tabbed::client_added", recreate)
	awesome.connect_signal("bling::tabbed::changed_focus", recreate)
	
	return tabbed_icons
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
						buttons = awful.button({}, 1, function()
							c:activate({ action = "toggle_minimization", context = "tasklist" })
						end),
					},
					nil,
					expand = "none",
					layout = wibox.layout.align.horizontal,
				},
				forced_width = opts.icon_size or dpi(24),
				forced_height = opts.icon_size or dpi(24),
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
		-- Seems to work uptil here

		-- Generate and add wrapper widget if > 1 children
		if #group.clients > 1 then

			local wrapper = wibox.widget(--[[opts.group_widget_template or ]]{
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
						spacing = opts.group_row_spacing or 2,
						layout = wibox.layout.fixed.vertical,
					},
					halign = "center",
					valign = "center",
					id = 'click_role',
					widget = wibox.container.place,
				},
				widget = wibox.container.margin,
				top = opts.group_margins.top or dpi(8),
				bottom = opts.group_margins.bottom or dpi(8),
				left = opts.group_margins.left or dpi(2),
				right = opts.group_margins.right or dpi(2),
			})

			for _, w in ipairs(wrapper:get_children_by_id('click_role')) do
				w:add_button(awful.button({}, 1, function()
						group.clients[group.focused_idx]:activate()
					end))
			end

			for idx, c in ipairs(group.clients) do
				if c and c.icon then
					-- TODO: Don't do this in a 1iq way
					if idx <= 2 then
						wrapper:get_children_by_id("row1")[1]:add(opts.group_icon_fn and opts.group_icon_fn(c) or awful.widget.clienticon(c))
					else
						wrapper:get_children_by_id("row2")[1]:add(opts.group_icon_fn and opts.group_icon_fn(c) or awful.widget.clienticon(c))
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
function module.custom_tasklist(s, opts)
	opts = opts or {
		group_margins = {}
	}
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

return module
