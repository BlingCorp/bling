local Gio = require("lgi").Gio
local awful = require("awful")
local gobject = require("gears.object")
local gtable = require("gears.table")
local gtimer = require("gears.timer")
local gfilesystem = require("gears.filesystem")
local wibox = require("wibox")
local beautiful = require("beautiful")
local color = require(tostring(...):match(".*bling") .. ".helpers.color")
local prompt = require(... .. ".prompt")
local dpi = beautiful.xresources.apply_dpi
local string = string
local table = table
local math = math
local ipairs = ipairs
local pairs = pairs
local capi = { screen = screen, mouse = mouse }
local path = ...

local app_launcher  = { mt = {} }

local KILL_OLD_INOTIFY_SCRIPT = [[ ps x | grep "inotifywait -e modify /usr/share/applications" | grep -v grep | awk '{print $1}' | xargs kill ]]
local INOTIFY_SCRIPT = [[ bash -c "while (inotifywait -e modify /usr/share/applications -qq) do echo; done" ]]
local AWESOME_SENSIBLE_TERMINAL_PATH = debug.getinfo(1).source:match("@?(.*/)") ..
                                           "awesome-sensible-terminal"

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

local function case_insensitive_pattern(pattern)
    -- find an optional '%' (group 1) followed by any character (group 2)
    local p = pattern:gsub("(%%?)(.)", function(percent, letter)
      if percent ~= "" or not letter:match("%a") then
        -- if the '%' matched, or `letter` is not a letter, return "as is"
        return percent .. letter
      else
        -- else, return a case-insensitive character class of the matched letter
        return string.format("[%s%s]", letter:lower(), letter:upper())
      end
    end)

    return p
end

local function has_value(tab, val)
    for index, value in pairs(tab) do
        if val:find(case_insensitive_pattern(value)) then
            return true
        end
    end
    return false
end

local function create_app_widget(self, app)
    local app_widget = nil

    if self.app_template == nil then
        local icon = self.app_show_icon == true and
        {
            widget = wibox.widget.imagebox,
            id = "icon_role",
            halign = self.app_icon_halign,
            forced_width = self.app_icon_width,
            forced_height = self.app_icon_height,
            image = app.icon
        } or nil

        local name = self.app_show_name == true and
        {
            widget = wibox.widget.textbox,
            id = "name_role",
            font = self.app_name_font,
            markup = string.format("<span foreground='%s'>%s</span>", self.app_name_normal_color, app.name)
        } or nil

        local generic_name = app.generic_name ~= nil and self.app_show_generic_name == true and
        {
            widget = wibox.widget.textbox,
            id = "generic_name_role",
            font = self.app_name_font,
            markup = app.generic_name ~= "" and "<span weight='300'> <i>(" .. app.generic_name .. ")</i></span>" or ""
        } or nil

        app_widget = wibox.widget
        {
            widget = wibox.container.background,
            id = "background_role",
            forced_width = self.app_width,
            forced_height = self.app_height,
            shape = self.app_shape,
            bg = self.app_normal_color,
            {
                widget = wibox.container.margin,
                margins = self.app_content_padding,
                {
                    -- Using this hack instead of container.place because that will fuck with the name/icon halign
                    layout = wibox.layout.align.vertical,
                    expand = "outside",
                    nil,
                    {
                        layout = wibox.layout.fixed.vertical,
                        spacing = self.app_content_spacing,
                        icon,
                        {
                            widget = wibox.container.place,
                            halign = self.app_name_halign,
                            {
                                layout = wibox.layout.fixed.horizontal,
                                spacing = self.app_name_generic_name_spacing,
                                name,
                                generic_name
                            }
                        }
                    },
                    nil
                }
            }
        }

        app_widget:connect_signal("mouse::enter", function()
            local widget = capi.mouse.current_wibox
            if widget then
                widget.cursor = "hand2"
            end

            if app_widget.selected then
                app_widget:get_children_by_id("background_role")[1].bg = self.app_selected_hover_color
            else
                app_widget:get_children_by_id("background_role")[1].bg = self.app_normal_hover_color
            end
        end)

        app_widget:connect_signal("mouse::leave", function()
            local widget = capi.mouse.current_wibox
            if widget then
                widget.cursor = "left_ptr"
            end

            if app_widget.selected then
                app_widget:get_children_by_id("background_role")[1].bg = self.app_selected_color
            else
                app_widget:get_children_by_id("background_role")[1].bg = self.app_normal_color
            end
        end)
    else
        app_widget = self.app_template(app)

        local icon = app_widget:get_children_by_id("icon_role")[1]
        if icon then
            icon.image = app.icon
        end
        local name = app_widget:get_children_by_id("name_role")[1]
        if name then
            name.text = app.name
        end
        local generic_name = app_widget:get_children_by_id("generic_name_role")[1]
        if generic_name then
            generic_name.text = app.generic_name
        end
        local command = app_widget:get_children_by_id("command_role")[1]
        if command then
            command.text = app.executable
        end
    end

    app_widget:connect_signal("button::press", function(app, _, __, button)
        if button == 1 then
            if self._private.active_widget == app or not self.select_before_spawn then
                app:spawn()
            else
                app:select()
            end
        end
    end)

    function app_widget:spawn()
        if app.terminal == true then
            awful.spawn.with_shell(AWESOME_SENSIBLE_TERMINAL_PATH .. " -e " .. app.executable)
        else
            awful.spawn(app.executable)
        end

        if self.hide_on_launch then
            self:hide()
        end
    end

    local _self = self
    function app_widget:select()
        if _self._private.active_widget then
            _self._private.active_widget:unselect()
        end
        _self._private.active_widget = self
        self:emit_signal("selected")
        self.selected = true

        if _self.app_template == nil then
            self:get_children_by_id("background_role")[1].bg = _self.app_selected_color
            local name_widget = self:get_children_by_id("name_role")[1]
            if name_widget then
                name_widget.markup = string.format("<span foreground='%s'>%s</span>", _self.app_name_selected_color, name_widget.text)
            end
            local generic_name_widget = self:get_children_by_id("generic_name_role")[1]
            if generic_name_widget then
                generic_name_widget.markup = string.format("<i><span weight='300'foreground='%s'>%s</span></i>", _self.app_name_selected_color, generic_name_widget.text)
            end
        end
    end

    function app_widget:unselect()
        self:emit_signal("unselected")
        self.selected = false
        _self._private.active_widget = nil

        if _self.app_template == nil then
            self:get_children_by_id("background_role")[1].bg = _self.app_normal_color
            local name_widget = self:get_children_by_id("name_role")[1]
            if name_widget then
                name_widget.markup = string.format("<span foreground='%s'>%s</span>", _self.app_name_normal_color, name_widget.text)
            end
            local generic_name_widget = self:get_children_by_id("generic_name_role")[1]
            if generic_name_widget then
                generic_name_widget.markup = string.format("<i><span weight='300'foreground='%s'>%s</span></i>", _self.app_name_normal_color, generic_name_widget.text)
            end
        end
    end

    return app_widget
end

local function search(self, text)
    local old_pos = self._private.grid:get_widget_position(self._private.active_widget)

    -- Reset all the matched entries
    self._private.matched_entries = {}
    -- Remove all the grid widgets
    self._private.grid:reset()

    if text == "" then
        self._private.matched_entries = self._private.all_entries
    else
        for _, entry in pairs(self._private.all_entries) do
            text = text:gsub( "%W", "" )

            -- Check if there's a match by the app name or app command
            if string.find(entry.name:lower(), text:lower(), 1, true) ~= nil or
                self.search_commands and string.find(entry.commandline, text:lower(), 1, true) ~= nil
            then
                table.insert(self._private.matched_entries, {
                    name = entry.name,
                    generic_name = entry.generic_name,
                    commandline = entry.commandline,
                    executable = entry.executable,
                    terminal = entry.terminal,
                    icon = entry.icon
                })
            end
        end

        -- Sort by string similarity
        table.sort(self._private.matched_entries, function(a, b)
            return string_levenshtein(text, a.name) < string_levenshtein(text, b.name)
        end)
    end
    for _, entry in pairs(self._private.matched_entries) do
        -- Only add the widgets for apps that are part of the first page
        if #self._private.grid.children + 1 <= self._private.max_apps_per_page then
            self._private.grid:add(create_app_widget(self, entry))
        end
    end

    -- Recalculate the apps per page based on the current matched entries
    self._private.apps_per_page = math.min(#self._private.matched_entries, self._private.max_apps_per_page)

    -- Recalculate the pages count based on the current apps per page
    self._private.pages_count = math.ceil(math.max(1, #self._private.matched_entries) / math.max(1, self._private.apps_per_page))

    -- Page should be 1 after a search
    self._private.current_page = 1

    -- This is an option to mimic rofi behaviour where after a search
    -- it will reselect the app whose index is the same as the app index that was previously selected
    -- and if matched_entries.length < current_index it will instead select the app with the greatest index
    if self.try_to_keep_index_after_searching then
        if self._private.grid:get_widgets_at(old_pos.row, old_pos.col) == nil then
            local app = self._private.grid.children[#self._private.grid.children]
            app:select()
        else
            local app = self._private.grid:get_widgets_at(old_pos.row, old_pos.col)[1]
            app:select()
        end
    -- Otherwise select the first app on the list
    else
        local app = self._private.grid:get_widgets_at(1, 1)[1]
        app:select()
    end
end

local function page_forward(self, direction)
    local min_app_index_to_include = 0
    local max_app_index_to_include = self._private.apps_per_page

    if self._private.current_page < self._private.pages_count then
        min_app_index_to_include = self._private.apps_per_page * self._private.current_page
        self._private.current_page = self._private.current_page + 1
        max_app_index_to_include = self._private.apps_per_page * self._private.current_page
    elseif self.wrap_page_scrolling and #self._private.matched_entries >= self._private.max_apps_per_page then
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

    for index, entry in pairs(self._private.matched_entries) do
        -- Only add widgets that are between this range (part of the current page)
        if index > min_app_index_to_include and index <= max_app_index_to_include then
            self._private.grid:add(create_app_widget(self, entry))
        end
    end

    if self._private.current_page > 1 or self.wrap_page_scrolling then
        if direction == "down" then
            local app = self._private.grid:get_widgets_at(1, 1)[1]
            app:select()
        else
            local app = self._private.grid:get_widgets_at(pos.row, 1)[1]
            if app == nil then
                local app = self._private.grid.children[#self._private.grid.children]
                app:select()
            else
                app:select()
            end
        end
    end
end

local function page_backward(self, direction)
    if self._private.current_page > 1 then
        self._private.current_page = self._private.current_page - 1
    elseif self.wrap_page_scrolling and #self._private.matched_entries >= self._private.max_apps_per_page then
        self._private.current_page = self._private.pages_count
    elseif self.wrap_app_scrolling then
        local app = self._private.grid.children{#self._private.grid.children}
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

    for index, entry in pairs(self._private.matched_entries) do
        -- Only add widgets that are between this range (part of the current page)
        if index > min_app_index_to_include and index <= max_app_index_to_include then
            self._private.grid:add(create_app_widget(self, entry))
        end
    end

    local rows, columns = self._private.grid:get_dimension()
    if self._private.current_page < self._private.pages_count then
        if direction == "up" then
            local app = self._private.grid.children{#self._private.grid.children}
            app:select()
        else
            -- Keep the same row from last page
            local app = self._private.grid:get_widgets_at(pos.row, columns)[1]
            app:select()
        end
    elseif self.wrap_page_scrolling then
        local app = self._private.grid.children[#self._private.grid.children]
        app:select()
    end
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
        step_size = -self.apps_per_row
        if_cant_scroll_func = function() page_backward(self, "left") end
    elseif dir == "right" then
        can_scroll = self._private.grid:get_widgets_at(pos.row, pos.col + 1) ~= nil
        step_size = self.apps_per_row
        if_cant_scroll_func = function() page_forward(self, "right") end
    end

    if can_scroll then
        local app = gtable.cycle_value(self._private.grid.children, self._private.active_widget, step_size)
        app:select()
    else
        if_cant_scroll_func()
    end
end

local function reset(self)
    self._private.grid:reset()
    self._private.matched_entries = self._private.all_entries
    self._private.apps_per_page = self._private.max_apps_per_page
    self._private.pages_count = math.ceil(#self._private.all_entries / self._private.apps_per_page)
    self._private.current_page = 1

    for index, entry in pairs(self._private.all_entries) do
        -- Only add the apps that are part of the first page
        if index <= self._private.apps_per_page then
            self._private.grid:add(create_app_widget(self, entry))
        else
            break
        end
    end

    local app = self._private.grid:get_widgets_at(1, 1)[1]
    app:select()
end

local function generate_apps(self)
    self._private.all_entries = {}
    self._private.matched_entries = {}

    local app_info = Gio.AppInfo
    local apps = app_info.get_all()
    if self.sort_alphabetically then
        table.sort(apps, function(a, b)
            local app_a_score = app_info.get_name(a):lower()
            if has_value(self.favorites, app_info.get_name(a)) then
                app_a_score = "aaaaaaaaaaa" .. app_a_score
            end
            local app_b_score = app_info.get_name(b):lower()
            if has_value(self.favorites, app_info.get_name(b)) then
                app_b_score = "aaaaaaaaaaa" .. app_b_score
            end

            return app_a_score < app_b_score
        end)
    elseif self.reverse_sort_alphabetically then
        table.sort(apps, function(a, b)
            local app_a_score = app_info.get_name(a):lower()
            if has_value(self.favorites, app_info.get_name(a)) then
                app_a_score = "zzzzzzzzzzz" .. app_a_score
            end
            local app_b_score = app_info.get_name(b):lower()
            if has_value(self.favorites, app_info.get_name(b)) then
                app_b_score = "zzzzzzzzzzz" .. app_b_score
            end

            return app_a_score > app_b_score
        end)
    else
        table.sort(apps, function(a, b)
            local app_a_favorite = has_value(self.favorites, app_info.get_name(a))
            local app_b_favorite = has_value(self.favorites, app_info.get_name(b))

            if app_a_favorite and not app_b_favorite then
                return true
            elseif app_b_favorite and not app_a_favorite then
                return false
            elseif app_a_favorite and app_b_favorite then
                return app_info.get_name(a):lower() < app_info.get_name(b):lower()
            else
                return false
            end
        end)
    end

    local icon_theme = require(tostring(path):match(".*bling") .. ".helpers.icon_theme")(self.icon_theme, self.icon_size)

    for _, app in ipairs(apps) do
        if app.should_show(app) then
            local name = app_info.get_name(app)
            local commandline = app_info.get_commandline(app)
            local executable = app_info.get_executable(app)
            local icon = icon_theme:get_gicon_path(app_info.get_icon(app))

            -- Check if this app should be skipped, depanding on the skip_names / skip_commands table
            if not has_value(self.skip_names, name) and not has_value(self.skip_commands, commandline) then
                -- Check if this app should be skipped becuase it's iconless depanding on skip_empty_icons
                if icon ~= "" or self.skip_empty_icons == false then
                    if icon == "" then
                        if self.default_app_icon_name ~= nil then
                            icon = icon_theme:get_icon_path(self.default_app_icon_name)
                        elseif self.default_app_icon_path ~= nil then
                            icon = self.default_app_icon_path
                        else
                            icon = icon_theme:choose_icon({"application-all", "application", "application-default-icon", "app"})
                        end
                    end

                    local desktop_app_info = Gio.DesktopAppInfo.new(app_info.get_id(app))
                    local terminal = Gio.DesktopAppInfo.get_string(desktop_app_info, "Terminal") == "true" and true or false
                    local generic_name = Gio.DesktopAppInfo.get_string(desktop_app_info, "GenericName") or nil

                    table.insert(self._private.all_entries, {
                        name = name,
                        generic_name = generic_name,
                        commandline = commandline,
                        executable = executable,
                        terminal = terminal,
                        icon = icon
                    })
                end
            end
        end
    end
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
    local screen = self.screen
    if self.show_on_focused_screen then
        screen = awful.screen.focused()
    end

    screen.app_launcher = self._private.widget
    screen.app_launcher.screen = screen
    self._private.prompt:start()

    local animation = self.rubato
    if animation ~= nil then
        if self._private.widget.goal_x == nil then
            self._private.widget.goal_x = self._private.widget.x
        end
        if self._private.widget.goal_y == nil then
            self._private.widget.goal_y = self._private.widget.y
            self._private.widget.placement = nil
        end

        if animation.x then
            animation.x.ended:unsubscribe()
            animation.x:set(self._private.widget.goal_x)
            gtimer {
                timeout = 0.01,
                call_now = false,
                autostart = true,
                single_shot = true,
                callback = function()
                    screen.app_launcher.visible = true
                end
            }
        end
        if animation.y then
            animation.y.ended:unsubscribe()
            animation.y:set(self._private.widget.goal_y)
            gtimer {
                timeout = 0.01,
                call_now = false,
                autostart = true,
                single_shot = true,
                callback = function()
                    screen.app_launcher.visible = true
                end
            }
        end
    else
        screen.app_launcher.visible = true
    end

    self:emit_signal("bling::app_launcher::visibility", true)
end

--- Hides the app launcher
function app_launcher:hide()
    local screen = self.screen
    if self.show_on_focused_screen then
        screen = awful.screen.focused()
    end

    if screen.app_launcher == nil or screen.app_launcher.visible == false then
        return
    end

    self._private.prompt:stop()

    local animation = self.rubato
    if animation ~= nil then
        if animation.x then
            animation.x:set(animation.x:initial())
        end
        if animation.y then
            animation.y:set(animation.y:initial())
        end

        local anim_x_duration = (animation.x and animation.x.duration) or 0
        local anim_y_duration = (animation.y and animation.y.duration) or 0
        local turn_off_on_anim_x_end = (anim_x_duration >= anim_y_duration) and true or false

        if turn_off_on_anim_x_end then
            animation.x.ended:subscribe(function()
                if self.reset_on_hide == true then reset(self) end
                screen.app_launcher.visible = false
                screen.app_launcher = nil
                animation.x.ended:unsubscribe()
            end)
        else
            animation.y.ended:subscribe(function()
                if self.reset_on_hide == true then reset(self) end
                screen.app_launcher.visible = false
                screen.app_launcher = nil
                animation.y.ended:unsubscribe()
            end)
        end
    else
        if self.reset_on_hide == true then reset(self) end
        screen.app_launcher.visible = false
        screen.app_launcher = nil
    end

    self:emit_signal("bling::app_launcher::visibility", false)
end

--- Toggles the app launcher
function app_launcher:toggle()
    local screen = self.screen
    if self.show_on_focused_screen then
        screen = awful.screen.focused()
    end

    if screen.app_launcher and screen.app_launcher.visible then
        self:hide()
    else
        self:show()
    end
end

-- Returns a new app launcher
local function new(args)
    args = args or {}

    args.favorites = args.favorites or {}
    args.search_commands = args.search_commands == nil and true or args.search_commands
    args.skip_names = args.skip_names or {}
    args.skip_commands = args.skip_commands or {}
    args.skip_empty_icons = args.skip_empty_icons ~= nil and args.skip_empty_icons or false
    args.sort_alphabetically = args.sort_alphabetically == nil and true or args.sort_alphabetically
    args.reverse_sort_alphabetically = args.reverse_sort_alphabetically ~= nil and args.reverse_sort_alphabetically or false
    args.select_before_spawn = args.select_before_spawn == nil and true or args.select_before_spawn
    args.hide_on_left_clicked_outside = args.hide_on_left_clicked_outside == nil and true or args.hide_on_left_clicked_outside
    args.hide_on_right_clicked_outside = args.hide_on_right_clicked_outside == nil and true or args.hide_on_right_clicked_outside
    args.hide_on_launch = args.hide_on_launch == nil and true or args.hide_on_launch
    args.try_to_keep_index_after_searching = args.try_to_keep_index_after_searching ~= nil and args.try_to_keep_index_after_searching or false
    args.reset_on_hide = args.reset_on_hide == nil and true or args.reset_on_hide
    args.save_history = args.save_history == nil and true or args.save_history
    args.wrap_page_scrolling = args.wrap_page_scrolling == nil and true or args.wrap_page_scrolling
    args.wrap_app_scrolling = args.wrap_app_scrolling == nil and true or args.wrap_app_scrolling

    args.type = args.type or "dock"
    args.show_on_focused_screen = args.show_on_focused_screen == nil and true or args.show_on_focused_screen
    args.screen = args.screen or capi.screen.primary
    args.placement = args.placement or awful.placement.centered
    args.rubato = args.rubato or nil
    args.background = args.background or "#000000"
    args.border_width = args.border_width or beautiful.border_width or dpi(0)
    args.border_color = args.border_color or beautiful.border_color or "#FFFFFF"
    args.shape = args.shape or nil

    args.prompt_height = args.prompt_height or dpi(100)
    args.prompt_margins = args.prompt_margins or dpi(0)
    args.prompt_paddings = args.prompt_paddings or dpi(30)
    args.prompt_shape = args.prompt_shape or nil
    args.prompt_color = args.prompt_color or beautiful.fg_normal or "#FFFFFF"
    args.prompt_border_width = args.prompt_border_width or beautiful.border_width or dpi(0)
    args.prompt_border_color = args.prompt_border_color or beautiful.border_color or args.prompt_color
    args.prompt_text_halign = args.prompt_text_halign or "left"
    args.prompt_text_valign = args.prompt_text_valign or "center"
    args.prompt_icon_text_spacing = args.prompt_icon_text_spacing or dpi(10)
    args.prompt_show_icon = args.prompt_show_icon == nil and true or args.prompt_show_icon
    args.prompt_icon_font = args.prompt_icon_font or beautiful.font
    args.prompt_icon_color = args.prompt_icon_color or beautiful.bg_normal or "#000000"
    args.prompt_icon = args.prompt_icon or ""
    args.prompt_icon_markup = args.prompt_icon_markup or string.format("<span size='xx-large' foreground='%s'>%s</span>", args.prompt_icon_color, args.prompt_icon)
    args.prompt_text = args.prompt_text or "<b>Search</b>: "
    args.prompt_start_text = args.prompt_start_text or ""
    args.prompt_font = args.prompt_font or beautiful.font
    args.prompt_text_color = args.prompt_text_color or beautiful.bg_normal or "#000000"
    args.prompt_cursor_color = args.prompt_cursor_color or beautiful.bg_normal or "#000000"

    args.default_app_icon_name = args.default_app_icon_name or nil
    args.default_app_icon_path = args.default_app_icon_path or nil
    args.icon_theme = args.icon_theme or nil
    args.icon_size = args.icon_size or nil

    args.apps_per_row = args.apps_per_row or 5
    args.apps_per_column = args.apps_per_column or 3
    args.apps_margin = args.apps_margin or dpi(30)
    args.apps_spacing = args.apps_spacing or dpi(30)
    args.expand_apps = args.expand_apps == nil and true or args.expand_apps

    args.app_width = args.app_width or dpi(300)
    args.app_height = args.app_height or dpi(120)
    args.app_shape = args.app_shape or nil
    args.app_normal_color = args.app_normal_color or beautiful.bg_normal or "#000000"
    args.app_normal_hover_color = args.app_normal_hover_color or (color.is_dark(args.app_normal_color) or color.is_opaque(args.app_normal_color)) and
        color.rgba_to_hex(color.multiply(color.hex_to_rgba(args.app_normal_color), 2.5)) or
        color.rgba_to_hex(color.multiply(color.hex_to_rgba(args.app_normal_color), 0.5))
    args.app_selected_color = args.app_selected_color or beautiful.fg_normal or "#FFFFFF"
    args.app_selected_hover_color = args.app_selected_hover_color or (color.is_dark(args.app_normal_color) or color.is_opaque(args.app_normal_color)) and
        color.rgba_to_hex(color.multiply(color.hex_to_rgba(args.app_selected_color), 2.5)) or
        color.rgba_to_hex(color.multiply(color.hex_to_rgba(args.app_selected_color), 0.5))
    args.app_content_padding = args.app_content_padding or dpi(10)
    args.app_content_spacing = args.app_content_spacing or dpi(10)
    args.app_show_icon = args.app_show_icon == nil and true or args.app_show_icon
    args.app_icon_halign = args.app_icon_halign or "center"
    args.app_icon_width = args.app_icon_width or dpi(70)
    args.app_icon_height = args.app_icon_height or dpi(70)
    args.app_show_name = args.app_show_name == nil and true or args.app_show_name
    args.app_name_generic_name_spacing = args.app_name_generic_name_spacing or dpi(0)
    args.app_name_halign = args.app_name_halign or "center"
    args.app_name_font = args.app_name_font or beautiful.font
    args.app_name_normal_color = args.app_name_normal_color or beautiful.fg_normal or "#FFFFFF"
    args.app_name_selected_color = args.app_name_selected_color or beautiful.bg_normal or "#000000"
    args.app_show_generic_name = args.app_show_generic_name ~= nil and args.app_show_generic_name or false

    local ret = gobject({})
    ret._private = {}
    ret._private.text = ""

    gtable.crush(ret, app_launcher)
    gtable.crush(ret, args)

    -- These widgets need to be later accessed
    ret._private.prompt = prompt
    {
        prompt = ret.prompt_text,
        text = ret.prompt_start_text,
        font = ret.prompt_font,
        reset_on_stop = ret.reset_on_hide,
        bg_cursor = ret.prompt_cursor_color,
        history_path = ret.save_history == true and gfilesystem.get_cache_dir() .. "/history" or nil,
        changed_callback = function(text)
            if text == ret._private.text then
                return
            end

            if ret._private.search_timer ~= nil and ret._private.search_timer.started then
                ret._private.search_timer:stop()
            end

            ret._private.search_timer = gtimer {
                timeout = 0.05,
                autostart = true,
                single_shot = true,
                callback = function()
                    search(ret, text)
                end
            }

            ret._private.text = text
        end,
        keypressed_callback = function(mod, key, cmd)
            if key == "Escape" then
                ret:hide()
            end
            if key == "Return" then
                if ret._private.active_widget ~= nil then
                    ret._private.active_widget:spawn()
                end
            end
            if key == "Up" then
                ret:scroll_up()
            end
            if key == "Down" then
                ret:scroll_down()
            end
            if key == "Left" then
                ret:scroll_left()
            end
            if key == "Right" then
                ret:scroll_right()
            end
        end
    }
    ret._private.grid = wibox.widget
    {
        layout = wibox.layout.grid,
        orientation = "horizontal",
        homogeneous = true,
        expand = ret.expand_apps,
        spacing = ret.apps_spacing,
        forced_num_cols = ret.apps_per_column,
        forced_num_rows = ret.apps_per_row,
        buttons =
        {
            awful.button({}, 4, function() ret:scroll_up() end),
            awful.button({}, 5, function() ret:scroll_down() end)
        }
    }
    ret._private.widget = awful.popup
    {
        type = args.type,
        visible = false,
        ontop = true,
        placement = ret.placement,
        border_width = ret.border_width,
        border_color = ret.border_color,
        shape = ret.shape,
        bg =  ret.background,
        widget =
        {
            layout = wibox.layout.fixed.vertical,
            {
                widget = wibox.container.margin,
                margins = ret.prompt_margins,
                {
                    widget = wibox.container.background,
                    forced_height = ret.prompt_height,
                    shape = ret.prompt_shape,
                    bg = ret.prompt_color,
                    fg = ret.prompt_text_color,
                    border_width = ret.prompt_border_width,
                    border_color = ret.prompt_border_color,
                    {
                        widget = wibox.container.margin,
                        margins = ret.prompt_paddings,
                        {
                            widget = wibox.container.place,
                            halign = ret.prompt_text_halign,
                            valign = ret.prompt_text_valign,
                            {
                                layout = wibox.layout.fixed.horizontal,
                                spacing = ret.prompt_icon_text_spacing,
                                {
                                    widget = wibox.widget.textbox,
                                    font = ret.prompt_icon_font,
                                    markup = ret.prompt_icon_markup
                                },
                                ret._private.prompt.textbox
                            }
                        }
                    }
                }
            },
            {
                widget = wibox.container.margin,
                margins = ret.apps_margin,
                ret._private.grid
            }
        }
    }

    -- Private variables to be used to be used by the scrolling and searching functions
    ret._private.max_apps_per_page = ret.apps_per_column * ret.apps_per_row
    ret._private.apps_per_page = ret._private.max_apps_per_page
    ret._private.pages_count = 0
    ret._private.current_page = 1

    if ret.rubato and ret.rubato.x then
        ret.rubato.x:subscribe(function(pos)
            ret._private.widget.x = pos
        end)
    end
    if ret.rubato and ret.rubato.y then
        ret.rubato.y:subscribe(function(pos)
            ret._private.widget.y = pos
        end)
    end

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

    generate_apps(ret)
    reset(ret)

    return ret
end

function app_launcher.text(args)
    args = args or {}

    args.prompt_height = args.prompt_height or dpi(50)
    args.prompt_margins = args.prompt_margins or dpi(30)
    args.prompt_paddings = args.prompt_paddings or dpi(15)
    args.app_width = args.app_width or dpi(400)
    args.app_height = args.app_height or dpi(40)
    args.apps_spacing = args.apps_spacing or dpi(10)
    args.apps_per_row = args.apps_per_row or 15
    args.apps_per_column = args.apps_per_column or 1
    args.app_name_halign = args.app_name_halign or "left"
    args.app_show_icon = args.app_show_icon ~= nil and args.app_show_icon or false
    args.app_show_generic_name = args.app_show_generic_name == nil and true or args.app_show_generic_name
    args.apps_margin = args.apps_margin or { left = dpi(40), right  = dpi(40), bottom = dpi(30) }

    return new(args)
end

function app_launcher.mt:__call(...)
    return new(...)
end

return setmetatable(app_launcher, app_launcher.mt)
