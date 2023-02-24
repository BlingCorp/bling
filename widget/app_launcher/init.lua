local Gio = require("lgi").Gio
local awful = require("awful")
local gobject = require("gears.object")
local gtable = require("gears.table")
local gtimer = require("gears.timer")
local wibox = require("wibox")
local beautiful = require("beautiful")
local prompt_widget = require(... .. ".prompt")
local dpi = beautiful.xresources.apply_dpi
local string = string
local table = table
local math = math
local ipairs = ipairs
local capi = { screen = screen, mouse = mouse }
local path = ...
local helpers = require(tostring(path):match(".*bling") .. ".helpers")

local app_launcher  = { mt = {} }

local KILL_OLD_INOTIFY_SCRIPT = [[ ps x | grep "inotifywait -e modify /usr/share/applications" | grep -v grep | awk '{print $1}' | xargs kill ]]
local INOTIFY_SCRIPT = [[ bash -c "while (inotifywait -e modify /usr/share/applications -qq) do echo; done" ]]
local AWESOME_SENSIBLE_TERMINAL_PATH = debug.getinfo(1).source:match("@?(.*/)") ..
                                           "awesome-sensible-terminal"

local function default_value(value, default)
    if value == nil then
        return default
    else
        return value
    end
end

local function string_levenshtein(str1, str2)
	local len1 = string.len(str1)
	local len2 = string.len(str2)
	local matrix = {}
	local cost = 0

    -- quick cut-offs to save time
	if (len1 == 0) then
		return len2
	elseif (len2 == 0) then
		return len1
	elseif (str1 == str2) then
		return 0
	end

    -- initialise the base matrix values
	for i = 0, len1, 1 do
		matrix[i] = {}
		matrix[i][0] = i
	end
	for j = 0, len2, 1 do
		matrix[0][j] = j
	end

    -- actual Levenshtein algorithm
	for i = 1, len1, 1 do
		for j = 1, len2, 1 do
			if (str1:byte(i) == str2:byte(j)) then
				cost = 0
			else
				cost = 1
			end

			matrix[i][j] = math.min(matrix[i-1][j] + 1, matrix[i][j-1] + 1, matrix[i-1][j-1] + cost)
		end
	end

    -- return the last value - this is the Levenshtein distance
	return matrix[len1][len2]
end

local function has_value(tab, val)
    for _, value in ipairs(tab) do
        if val:lower():find(value:lower(), 1, true) then
            return true
        end
    end
    return false
end

local function app_widget(self, app)
    local widget = nil

    if self.app_template == nil then
        widget = wibox.widget
        {
            widget = wibox.container.background,
            forced_width = dpi(300),
            forced_height = dpi(120),
            bg = self.app_normal_color,
            {
                widget = wibox.container.margin,
                margins = dpi(10),
                {
                    layout = wibox.layout.fixed.vertical,
                    spacing = dpi(10),
                    {
                        widget = wibox.container.place,
                        halign = "center",
                        valign = "center",
                        {
                            widget = wibox.widget.imagebox,
                            id = "icon_role",
                            forced_width = dpi(70),
                            forced_height = dpi(70),
                            image = app.icon
                        },
                    },
                    {
                        widget = wibox.container.place,
                        halign = "center",
                        valign = "center",
                        {
                            widget = wibox.widget.textbox,
                            id = "name_role",
                            markup = string.format("<span foreground='%s'>%s</span>", self.app_name_normal_color, app.name)
                        }
                    }
                }
            }
        }

        widget:connect_signal("mouse::enter", function()
            local widget = capi.mouse.current_wibox
            if widget then
                widget.cursor = "hand2"
            end
        end)

        widget:connect_signal("mouse::leave", function()
            local widget = capi.mouse.current_wibox
            if widget then
                widget.cursor = "left_ptr"
            end
        end)
    else
        widget = self.app_template(app)
    end

    widget:connect_signal("button::press", function(app, _, __, button)
        if button == 1 then
            if self._private.active_widget == app or not self.select_before_spawn then
                app:spawn()
            else
                app:select()
            end
        end
    end)

    local _self = self
    function widget:spawn()
        if app.terminal == true then
            awful.spawn.with_shell(AWESOME_SENSIBLE_TERMINAL_PATH .. " -e " .. app.exec)
        else
            awful.spawn(app.exec)
        end

        if _self.hide_on_launch then
            _self:hide()
        end
    end

    function widget:select()
        if _self._private.active_widget then
            _self._private.active_widget:unselect()
        end
        _self._private.active_widget = self
        self:emit_signal("selected")
        self.selected = true

        if _self.app_template == nil then
            widget.bg = _self.app_selected_color
            local name_widget = self:get_children_by_id("name_role")[1]
            name_widget.markup = string.format("<span foreground='%s'>%s</span>", _self.app_name_selected_color, name_widget.text)
        end
    end

    function widget:unselect()
        self:emit_signal("unselected")
        self.selected = false
        _self._private.active_widget = nil

        if _self.app_template == nil then
            widget.bg = _self.app_normal_color
            local name_widget = self:get_children_by_id("name_role")[1]
            name_widget.markup = string.format("<span foreground='%s'>%s</span>", _self.app_name_normal_color, name_widget.text)
        end
    end

    app.spawn = widget.spawn
    app.select = widget.select
    app.unselect = widget.unselect

    return widget
end

local function search(self)
    local text = self._private.text
    local old_pos = self._private.grid:get_widget_position(self._private.active_widget)

    -- Reset all the matched apps
    self._private.matched_apps = {}
    -- Remove all the grid widgets
    self._private.grid:reset()

    if text == "" then
        self._private.matched_apps = self._private.all_apps
    else
        for _, app in ipairs(self._private.all_apps) do
            text = text:gsub( "%W", "" )

            -- Check if there's a match by the app name or app command
            if string.find(app.name:lower(), text:lower(), 1, true) ~= nil or
                self.search_commands and string.find(app.exec, text:lower(), 1, true) ~= nil
            then
                table.insert(self._private.matched_apps, app)
            end
        end

        -- Sort by string similarity
        table.sort(self._private.matched_apps, function(a, b)
            return string_levenshtein(text, a.name) < string_levenshtein(text, b.name)
        end)
    end
    for _, app in ipairs(self._private.matched_apps) do
        -- Only add the widgets for apps that are part of the first page
        if #self._private.grid.children + 1 <= self._private.max_apps_per_page then
            self._private.grid:add(app_widget(self, app))
        end
    end

    -- Recalculate the apps per page based on the current matched apps
    self._private.apps_per_page = math.min(#self._private.matched_apps, self._private.max_apps_per_page)

    -- Recalculate the pages count based on the current apps per page
    self._private.pages_count = math.ceil(math.max(1, #self._private.matched_apps) / math.max(1, self._private.apps_per_page))

    -- Page should be 1 after a search
    self._private.current_page = 1

    -- This is an option to mimic rofi behaviour where after a search
    -- it will reselect the app whose index is the same as the app index that was previously selected
    -- and if matched_apps.length < current_index it will instead select the app with the greatest index
    if self.try_to_keep_index_after_searching then
        if self._private.grid:get_widgets_at(old_pos.row, old_pos.col) == nil then
            local app = self._private.grid.children[#self._private.grid.children]
            app:select()
        else
            local app = self._private.grid:get_widgets_at(old_pos.row, old_pos.col)[1]
            app:select()
        end
    -- Otherwise select the first app on the list
    elseif #self._private.grid.children > 0 then
        local app = self._private.grid:get_widgets_at(1, 1)[1]
        app:select()
    end
end

local function page_forward(self, dir)
    local min_app_index_to_include = 0
    local max_app_index_to_include = self._private.apps_per_page

    if self._private.current_page < self._private.pages_count then
        min_app_index_to_include = self._private.apps_per_page * self._private.current_page
        self._private.current_page = self._private.current_page + 1
        max_app_index_to_include = self._private.apps_per_page * self._private.current_page
    elseif self.wrap_page_scrolling and #self._private.matched_apps >= self._private.max_apps_per_page then
        self._private.current_page = 1
        min_app_index_to_include = 0
        max_app_index_to_include = self._private.apps_per_page
    elseif self.wrap_app_scrolling then
        local app = self._private.grid:get_widgets_at(1, 1)[1]
        app:select()
        return
    else
        return
    end

    local pos = self._private.grid:get_widget_position(self._private.active_widget)

    -- Remove the current page apps from the grid
    self._private.grid:reset()

    for index, app in ipairs(self._private.matched_apps) do
        -- Only add widgets that are between this range (part of the current page)
        if index > min_app_index_to_include and index <= max_app_index_to_include then
            self._private.grid:add(app_widget(self, app))
        end
    end

    if self._private.current_page > 1 or self.wrap_page_scrolling then
        local app = nil
        if dir == "down" then
            app = self._private.grid:get_widgets_at(1, 1)[1]
        elseif dir == "right" then
            app = self._private.grid:get_widgets_at(pos.row, 1)
            if app then
                app = app[1]
            end
            if app == nil then
                app = self._private.grid.children[#self._private.grid.children]
            end
        end
        app:select()
    end
end

local function page_backward(self, dir)
    if self._private.current_page > 1 then
        self._private.current_page = self._private.current_page - 1
    elseif self.wrap_page_scrolling and #self._private.matched_apps >= self._private.max_apps_per_page then
        self._private.current_page = self._private.pages_count
    elseif self.wrap_app_scrolling then
        local app = self._private.grid.children[#self._private.grid.children]
        app:select()
        return
    else
        return
    end

    local pos = self._private.grid:get_widget_position(self._private.active_widget)

    -- Remove the current page apps from the grid
    self._private.grid:reset()

    local max_app_index_to_include = self._private.apps_per_page * self._private.current_page
    local min_app_index_to_include = max_app_index_to_include - self._private.apps_per_page

    for index, app in ipairs(self._private.matched_apps) do
        -- Only add widgets that are between this range (part of the current page)
        if index > min_app_index_to_include and index <= max_app_index_to_include then
            self._private.grid:add(app_widget(self, app))
        end
    end

    local app = nil
    if self._private.current_page < self._private.pages_count then
        if dir == "up" then
            app = self._private.grid.children[#self._private.grid.children]
        else
            -- Keep the same row from last page
            local _, columns = self._private.grid:get_dimension()
            app = self._private.grid:get_widgets_at(pos.row, columns)[1]
        end
    elseif self.wrap_page_scrolling then
        app = self._private.grid.children[#self._private.grid.children]
    end
    app:select()
end

local function scroll(self, dir)
    if #self._private.grid.children < 1 then
        self._private.active_widget = nil
        return
    end

    local pos = self._private.grid:get_widget_position(self._private.active_widget)
    local can_scroll = false
    local step_size = 0
    local if_cant_scroll_func = nil

    if dir == "up" then
        can_scroll = self._private.grid:index(self._private.active_widget) > 1
        step_size = -1
        if_cant_scroll_func = function() page_backward(self, "up") end
    elseif dir == "down" then
        can_scroll = self._private.grid:index(self._private.active_widget) < #self._private.grid.children
        step_size = 1
        if_cant_scroll_func = function() page_forward(self, "down") end
    elseif dir == "left" then
        can_scroll = self._private.grid:get_widgets_at(pos.row, pos.col - 1) ~= nil
        step_size = -self._private.grid.forced_num_rows
        if_cant_scroll_func = function() page_backward(self, "left") end
    elseif dir == "right" then
        can_scroll = self._private.grid:get_widgets_at(pos.row, pos.col + 1) ~= nil
        step_size = self._private.grid.forced_num_cols
        if_cant_scroll_func = function() page_forward(self, "right") end
    end

    if can_scroll then
        local app = gtable.cycle_value(self._private.grid.children, self._private.active_widget, step_size)
        app:select()
    else
        if_cant_scroll_func()
    end
end

local function sort_apps(self)
    table.sort(self._private.all_apps, function(a, b)
        local is_a_favorite = has_value(self.favorites, a.id)
        local is_b_favorite = has_value(self.favorites, b.id)

        -- Sort the favorite apps first
        if is_a_favorite and not is_b_favorite then
            return true
        elseif not is_a_favorite and is_b_favorite then
            return false
        end

        -- Sort alphabetically if specified
        if self.sort_alphabetically then
            return a.name:lower() < b.name:lower()
        elseif self.reverse_sort_alphabetically then
            return b.name:lower() > a.name:lower()
        else
            return true
        end
    end)
end

local function generate_apps(self)
    self._private.all_apps = {}
    self._private.matched_apps = {}

    local app_info = Gio.AppInfo
    local apps = app_info.get_all()
    for _, app in ipairs(apps) do
        if app:should_show() then
            local id = app:get_id()
            local desktop_app_info = Gio.DesktopAppInfo.new(id)
            local name = desktop_app_info:get_string("Name")
            local exec = desktop_app_info:get_string("Exec")

            -- Check if this app should be skipped, depanding on the skip_names / skip_commands table
            if not has_value(self.skip_names, name) and not has_value(self.skip_commands, exec) then
                -- Check if this app should be skipped becuase it's iconless depanding on skip_empty_icons
                local icon = helpers.icon_theme.get_gicon_path(app_info.get_icon(app), self.icon_theme, self.icon_size)
                if icon ~= "" or self.skip_empty_icons == false then
                    if icon == "" then
                        if self.default_app_icon_name ~= nil then
                            icon = helpers.icon_theme.get_icon_path(self.default_app_icon_name, self.icon_theme, self.icon_size)
                        elseif self.default_app_icon_path ~= nil then
                            icon = self.default_app_icon_path
                        else
                            icon = helpers.icon_theme.choose_icon(
                                {"application-all", "application", "application-default-icon", "app"},
                                self.icon_theme, self.icon_size)
                        end
                    end

                    table.insert(self._private.all_apps, {
                        desktop_app_info = desktop_app_info,
                        path = desktop_app_info:get_filename(),
                        id = id,
                        name = name,
                        generic_name = desktop_app_info:get_string("GenericName"),
                        startup_wm_class = desktop_app_info:get_startup_wm_class(),
                        keywords = desktop_app_info:get_string("Keywords"),
                        icon = icon,
                        icon_name = desktop_app_info:get_string("Icon"),
                        terminal = desktop_app_info:get_string("Terminal") == "true" and true or false,
                        exec = exec,
                    })
                end
            end
        end
    end

    sort_apps(self)
end

local function build_widget(self)
    local widget = self.widget_template
    if widget == nil then
        self._private.prompt = wibox.widget
        {
            widget = prompt_widget,
            always_on = true,
            reset_on_stop = self.reset_on_hide,
            icon_font = self.prompt_icon_font,
            icon_size = self.prompt_icon_size,
            icon_color = self.prompt_icon_color,
            icon = self.prompt_icon,
            label_font = self.prompt_label_font,
            label_size = self.prompt_label_size,
            label_color = self.prompt_label_color,
            label = self.prompt_label,
            text_font = self.prompt_text_font,
            text_size = self.prompt_text_size,
            text_color = self.prompt_text_color,
        }
        self._private.grid = wibox.widget
        {
            layout = wibox.layout.grid,
            orientation = "horizontal",
            homogeneous = true,
            spacing = dpi(30),
            forced_num_cols = self.apps_per_column,
            forced_num_rows = self.apps_per_row,
        }
        widget = wibox.widget
        {
            layout = wibox.layout.fixed.vertical,
            {
                widget = wibox.container.background,
                forced_height = dpi(120),
                bg = self.prompt_bg_color,
                {
                    widget = wibox.container.margin,
                    margins = dpi(30),
                    {
                        widget = wibox.container.place,
                        halign = "left",
                        valign = "center",
                        self._private.prompt
                    }
                }
            },
            {
                widget = wibox.container.margin,
                margins = dpi(30),
                self._private.grid
            }
        }
    else
        self._private.prompt = widget:get_children_by_id("prompt_role")[1]
        self._private.grid = widget:get_children_by_id("grid_role")[1]
    end

    self._private.widget = awful.popup
    {
        screen = self.screen,
        type = self.type,
        visible = false,
        ontop = true,
        placement = self.placement,
        border_width = self.border_width,
        border_color = self.border_color,
        shape = self.shape,
        bg =  self.bg,
        widget = widget
    }

    self._private.grid:connect_signal("button::press", function(_, lx, ly, button, mods, find_widgets_result)
        if button == 4 then
            self:scroll_up()
        elseif button == 5 then
            self:scroll_down()
        end
    end)

    self._private.prompt:connect_signal("text::changed", function(_, text)
        if text == self._private.text then
            return
        end

        self._private.text = text
        self._private.search_timer:again()
    end)

    self._private.prompt:connect_signal("key::release", function(_, mod, key, cmd)
        if key == "Escape" then
            self:hide()
        end
        if key == "Return" then
            if self._private.active_widget ~= nil then
                self._private.active_widget:spawn()
            end
        end
        if key == "Up" then
            self:scroll_up()
        end
        if key == "Down" then
            self:scroll_down()
        end
        if key == "Left" then
            self:scroll_left()
        end
        if key == "Right" then
            self:scroll_right()
        end
    end)

    self._private.max_apps_per_page = self._private.grid.forced_num_cols * self._private.grid.forced_num_rows
    self._private.apps_per_page = self._private.max_apps_per_page
end

-- Sets favorites
function app_launcher:set_favorites(favorites)
    self.favorites = favorites
    sort_apps(self)
    -- Refresh the app list
    search(self)
end

--- Scrolls up
function app_launcher:scroll_up()
    scroll(self, "up")
end

--- Scrolls down
function app_launcher:scroll_down()
    scroll(self, "down")
end

--- Scrolls to the left
function app_launcher:scroll_left()
    scroll(self, "left")
end

--- Scrolls to the right
function app_launcher:scroll_right()
    scroll(self, "right")
end

--- Shows the app launcher
function app_launcher:show()
    if self.show_on_focused_screen then
        self._private.widget.screen = awful.screen.focused()
    end

    self._private.widget.visible = true
    self._private.prompt:start()
    self:emit_signal("visibility", true)
end

--- Hides the app launcher
function app_launcher:hide()
    if self._private.widget.visible == false then
        return
    end

    if self.reset_on_hide == true then
        self:reset()
    end

    self._private.widget.visible = false
    self._private.prompt:stop()
    self:emit_signal("visibility", false)
end

--- Toggles the app launcher
function app_launcher:toggle()
    if self._private.widget.visible then
        self:hide()
    else
        self:show()
    end
end

-- Reset the app page into the initial state
function app_launcher:reset()
    self._private.grid:reset()
    self._private.matched_apps = self._private.all_apps
    self._private.apps_per_page = self._private.max_apps_per_page
    self._private.pages_count = math.ceil(#self._private.all_apps / self._private.apps_per_page)
    self._private.current_page = 1

    for index, app in ipairs(self._private.all_apps) do
        -- Only add the apps that are part of the first page
        if index <= self._private.apps_per_page then
            self._private.grid:add(app_widget(self, app))
        else
            break
        end
    end

    local app = self._private.grid:get_widgets_at(1, 1)[1]
    app:select()

    self._private.prompt:set_text("")
end

-- Returns a new app launcher
local function new(args)
    args = args or {}

    args.favorites = default_value(args.favorites, {})
    args.search_commands = default_value(args.search_commands, true)
    args.skip_names = default_value(args.skip_names, {})
    args.skip_commands = default_value(args.skip_commands, {})
    args.skip_empty_icons = default_value(args.skip_empty_icons, false)
    args.sort_alphabetically = default_value(args.sort_alphabetically, true)
    args.reverse_sort_alphabetically = default_value(args.reverse_sort_alphabetically, false)
    args.select_before_spawn = default_value(args.select_before_spawn, true)
    args.hide_on_left_clicked_outside = default_value(args.hide_on_left_clicked_outside, true)
    args.hide_on_right_clicked_outside = default_value(args.hide_on_right_clicked_outside, true)
    args.hide_on_launch = default_value(args.hide_on_launch, true)
    args.try_to_keep_index_after_searching = default_value(args.try_to_keep_index_after_searching, false)
    args.reset_on_hide = default_value(args.reset_on_hide, true)
    args.wrap_page_scrolling = default_value(args.wrap_page_scrolling, true)
    args.wrap_app_scrolling = default_value(args.wrap_app_scrolling, true)

    args.type = default_value(args.type, "dock")
    args.show_on_focused_screen = default_value(args.show_on_focused_screen, true)
    args.screen = default_value(args.screen, capi.screen.primary)
    args.placement = default_value(args.placement, awful.placement.centered)
    args.bg = default_value(args.bg, "#000000")
    args.border_width = default_value(args.border_width, beautiful.border_width or dpi(0))
    args.border_color = default_value(args.border_color, beautiful.border_color or "#FFFFFF")
    args.shape = default_value(args.shape, nil)

    args.default_app_icon_name = default_value(args.default_app_icon_name, nil)
    args.default_app_icon_path = default_value(args.default_app_icon_path, nil)
    args.icon_theme = default_value(args.icon_theme, nil)
    args.icon_size = default_value(args.icon_size, nil)

    args.apps_per_row = default_value(args.apps_per_row, 5)
    args.apps_per_column = default_value(args.apps_per_column, 3)

    args.prompt_bg_color = default_value(args.prompt_bg_color, "#000000")
    args.prompt_icon_font = default_value(args.prompt_icon_font, beautiful.font)
    args.prompt_icon_size = default_value(args.prompt_icon_size, 12)
    args.prompt_icon_color = default_value(args.prompt_icon_color, "#FFFFFF")
    args.prompt_icon = default_value(args.prompt_icon, "")
    args.prompt_label_font = default_value(args.prompt_label_font, beautiful.font)
    args.prompt_label_size = default_value(args.prompt_label_size, 12)
    args.prompt_label_color = default_value(args.prompt_label_color, "#FFFFFF")
    args.prompt_label = default_value(args.prompt_label, "<b>Search</b>: ")
    args.prompt_text_font = default_value(args.prompt_text_font, beautiful.font)
    args.prompt_text_size = default_value(args.prompt_text_size, 12)
    args.prompt_text_color = default_value(args.prompt_text_color, "#FFFFFF")

    args.app_normal_color = default_value(args.app_normal_color, "#000000")
    args.app_selected_color = default_value(args.app_selected_color, "#FFFFFF")
    args.app_name_normal_color = default_value( args.app_name_normal_color, "#FFFFFF")
    args.app_name_selected_color = default_value(args.app_name_selected_color, "#000000")

    local ret = gobject {}
    gtable.crush(ret, app_launcher, true)
    gtable.crush(ret, args, true)

    ret._private = {}
    ret._private.text = ""
    ret._private.pages_count = 0
    ret._private.current_page = 1
    ret._private.search_timer = gtimer {
        timeout = 0.05,
        autostart = true,
        single_shot = true,
        callback = function()
            search(ret)
        end
    }

    if ret.hide_on_left_clicked_outside then
        awful.mouse.append_client_mousebinding(
            awful.button({ }, 1, function (c)
                ret:hide()
            end)
        )

        awful.mouse.append_global_mousebinding(
            awful.button({ }, 1, function (c)
                ret:hide()
            end)
        )
    end
    if ret.hide_on_right_clicked_outside then
        awful.mouse.append_client_mousebinding(
            awful.button({ }, 3, function (c)
                ret:hide()
            end)
        )

        awful.mouse.append_global_mousebinding(
            awful.button({ }, 3, function (c)
                ret:hide()
            end)
        )
    end

    awful.spawn.easy_async_with_shell(KILL_OLD_INOTIFY_SCRIPT, function()
        awful.spawn.with_line_callback(INOTIFY_SCRIPT, {stdout = function()
            generate_apps(ret)
        end})
    end)

    build_widget(ret)
    generate_apps(ret)
    ret:reset()

    return ret
end

function app_launcher.mt:__call(...)
    return new(...)
end

return setmetatable(app_launcher, app_launcher.mt)
