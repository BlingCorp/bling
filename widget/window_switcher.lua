local cairo = require("lgi").cairo
local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local beautiful = require("beautiful")
local helpers = require(tostring(...):match(".*bling") .. ".helpers")
local dpi = beautiful.xresources.apply_dpi

local window_switcher_first_client -- The client that was focused when the window_switcher was activated
local window_switcher_minimized_clients = {} -- The clients that were minimized when the window switcher was activated
local window_switcher_grabber

local task_preview = require(tostring(...):match(".*bling") .. ".widget.task_preview")

local get_num_clients = function()
  local minimized_clients_in_tag = 0
  local matcher = function(c)
	return awful.rules.match(
	  c,
	  {
		minimized = true,
		skip_taskbar = false,
		hidden = false,
		first_tag = awful.screen.focused().selected_tag,
	  }
	)
  end
  for c in awful.client.iterate(matcher) do
	minimized_clients_in_tag = minimized_clients_in_tag + 1
  end
  return minimized_clients_in_tag + #awful.screen.focused().clients
end

local window_switcher_hide = function(window_switcher_box)
  -- Add currently focused client to history
  if client.focus then
	local window_switcher_last_client = client.focus
	awful.client.focus.history.add(window_switcher_last_client)
	-- Raise client that was focused originally
	-- Then raise last focused client
	if
	  window_switcher_first_client and window_switcher_first_client.valid
	then
	  window_switcher_first_client:raise()
	  window_switcher_last_client:raise()
	end
  end

  -- Minimize originally minimized clients
  local s = awful.screen.focused()
  for _, c in pairs(window_switcher_minimized_clients) do
	if c and c.valid and not (client.focus and client.focus == c) then
	  c.minimized = true
	end
  end
  -- Reset helper table
  window_switcher_minimized_clients = {}

  -- Resume recording focus history
  awful.client.focus.history.enable_tracking()
  -- Stop and hide window_switcher
  awful.keygrabber.stop(window_switcher_grabber)
  window_switcher_box.visible = false
end

local function draw_widget(opts)

  return awful.widget.tasklist {
	screen = awful.screen.focused(),
	filter = awful.widget.tasklist.filter.currenttags,
	buttons = opts.mouse_buttons,
	style = opts.tasklist_style,
	layout = opts.tasklist_layout,
	widget_template = {
	  widget = wibox.container.background,
	  create_callback = function(self, c)
		self.widget = task_preview.draw_widget(c, opts.task_preview_opts)
	  end
	}
  } 
end

local enable = function(opts)
  opts = opts or {}


  local opts = helpers.util.retrieveArguments({
	"window_switcher",
	".*_key",
	background = "#000000",
	border_width = 1,
	border_color = "#ffffff",

	-- NES: Cut out most of the arguments here since not necessary, user can modify them in widget_template
	box_margins = 10,
	box_maximum_height = dpi(300),
	tasklist_style = {
	  fg_focus = "#ff0000"
	},
	tasklist_layout = nil,
	task_preview_opts = {
	  widget_template = {
		{
		  -- NES: Constraint is required to give the bottom bits space to breathe.
		  {
		  widget = wibox.widget.imagebox,
		  id = 'image_role'
		},
		  widget = wibox.container.constraint,
		  height = 270
		},
		{
		  layout = wibox.layout.fixed.horizontal,
		  {
			widget = wibox.widget.imagebox,
			id = 'icon_role'
		  },
		  {
			widget = wibox.widget.textbox,
			id = 'name_role'
		  }
		},
		layout = wibox.layout.fixed.vertical
	  }
	}, 

	hide_window_switcher_key = "Escape",

	-- NES: Felt like it was missing so added it
	placement = awful.placement.centered,
	box_shape = gears.shape.rectangle,
	exit_on_modifier_release = false,
	
	minimize_key = 'n',
	unminimize_key = "N",
	kill_client_key = "q",
	cycle_key = "Tab",
	previous_key = "Left",
	next_key = "Right",

	vim_previous_key = "h",
	vim_next_key = "l",

	-- NES: Renamed these
	select_client_btn = 1,
	scroll_previous_btn = 4,
	scroll_next_btn = 5
  }, opts)

  local window_switcher_box = awful.popup({
	bg = opts.background,
	maximum_height = opts.box_maximum_height,
	visible = false,
	ontop = true,
	placement = opts.placement,
	screen = awful.screen.focused(),
	-- NES: You redefine it anyway, what exactly is the point?
	-- widget = wibox.container.background, -- A dummy widget to make awful.popup not scream
	widget = {
	  draw_widget(opts),
	  margins = opts.box_margins,
	  widget = wibox.container.margin,
	},
	border_width = opts.border_width,
	border_color = opts.border_color,
	bg = background,
	shape = opts.box_shape
  })

  -- NES: Removed the 'Any' since it served no purpose
  -- NES: Also renamed this
  opts.mouse_buttons = gears.table.join(
	awful.button({ },
	  opts.select_client_btn,
	  function(c)
		client.focus = c
	end),

	awful.button({}, opts.scroll_previous_btn, function()
	  awful.client.focus.byidx(-1)
	end
	),

	awful.button({},opts.scroll_next_btn,function()
	  awful.client.focus.byidx(1)
	end)
  )

  opts.keyboard_keys = {
	[opts.hide_window_switcher_key] = function()
	  window_switcher_hide(window_switcher_box)
	end,

	[opts.minimize_key] = function()
	  if client.focus then
		client.focus.minimized = true
	  end
	end,
	[opts.unminimize_key] = function()
	  if awful.client.restore() then
		client.focus = awful.client.restore()
	  end
	end,
	[opts.kill_client_key] = function()
	  if client.focus then
		client.focus:kill()
	  end
	end,

	[opts.cycle_key] = function()
	  awful.client.focus.byidx(1)
	end,

	[opts.previous_key] = function()
	  awful.client.focus.byidx(1)
	end,
	[opts.next_key] = function()
	  awful.client.focus.byidx(-1)
	end,

	[opts.vim_previous_key] = function()
	  awful.client.focus.byidx(1)
	end,
	[opts.vim_next_key] = function()
	  awful.client.focus.byidx(-1)
	end,
  }

  window_switcher_box:connect_signal("property::width", function()
	if window_switcher_box.visible and get_num_clients() == 0 then
	  window_switcher_hide(window_switcher_box)
	end
  end)

  window_switcher_box:connect_signal("property::height", function()
	if window_switcher_box.visible and get_num_clients() == 0 then
	  window_switcher_hide(window_switcher_box)
	end
  end)

  awesome.connect_signal("bling::window_switcher::show", function()
	local number_of_clients = get_num_clients()
	if number_of_clients == 0 then
	  return
	end

	-- Store client that is focused in a variable
	window_switcher_first_client = client.focus

	-- Stop recording focus history
	awful.client.focus.history.disable_tracking()

	-- Go to previously focused client (in the tag)
	awful.client.focus.history.previous()

	-- Track minimized clients
	-- Unminimize them
	-- Lower them so that they are always below other
	-- originally unminimized windows
	local clients = awful.screen.focused().selected_tag:clients()
	for _, c in pairs(clients) do
	  if c.minimized then
		table.insert(window_switcher_minimized_clients, c)
		c.minimized = false
		c:lower()
	  end
	end

	-- Start the keygrabber
	window_switcher_grabber = awful.keygrabber.run(function(_, key, event)
	  if event == "release" and opts.exit_on_modifier_release then
		-- Hide if the modifier was released
		-- We try to match Super or Alt or Control since we do not know which keybind is
		-- -- used to activate the window switcher (the keybind is set by the user in keys.lua)
		if
		  key:match("Super")
		  or key:match("Alt")
		  or key:match("Control")
		then
		  window_switcher_hide(window_switcher_box)
		end
		-- Do nothing
	  end

	  -- Run function attached to key, if it exists
	  if opts.keyboard_keys[key] then
		opts.keyboard_keys[key]()
	  end

	  -- return true -- NES: Continue mouse grabbing
	end)

	-- NES: Removed the abomination that was here
	window_switcher_box.widget = draw_widget(opts)
	window_switcher_box.visible = true
  end)
end

-- NES: Can't we just return the function directly
return { enable = enable }
