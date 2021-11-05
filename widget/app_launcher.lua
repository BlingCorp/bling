local Gio = require("lgi").Gio
local awful = require("awful")
local gobject = require("gears.object")
local gtable = require("gears.table")
local gtimer = require("gears.timer")
local wibox = require("wibox")
local beautiful = require("beautiful")
local color = require(tostring(...):match(".*bling") .. ".helpers.color")
local dpi = beautiful.xresources.apply_dpi
local string = string
local table = table
local math = math
local ipairs = ipairs
local pairs = pairs
local root = root
local capi = { screen = screen, mouse = mouse }
local path = ...

local app_launcher  = { mt = {} }

local terminal_commands_lookup =
{
    alacritty = "alacritty -e",
    termite = "termite -e",
    rxvt = "rxvt -e",
    terminator = "terminator -e"
}

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
    for index, value in pairs(tab) do
        if val:find(value) then
            return true
        end
    end
    return false
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

local function select_app(self, x, y)
    local widgets = self._private.grid:get_widgets_at(x, y)
    if widgets then
        self._private.active_widget = widgets[1]
        if self._private.active_widget ~= nil then
            self._private.active_widget.selected = true
            self._private.active_widget:get_children_by_id("background")[1].bg = self.app_selected_color
            local text_widget = self._private.active_widget:get_children_by_id("text")[1]
            text_widget.markup = "<span foreground='" .. self.app_name_selected_color .. "'>" .. text_widget.text .. "</span>"
        end
    end
end

local function unselect_app(self)
    if self._private.active_widget ~= nil then
        self._private.active_widget.selected = false
        self._private.active_widget:get_children_by_id("background")[1].bg = self.app_normal_color
        local text_widget = self._private.active_widget:get_children_by_id("text")[1]
        text_widget.markup = "<span foreground='" .. self.app_name_normal_color .. "'>" .. text_widget.text .. "</span>"
        self._private.active_widget = nil
    end
end

local function create_app_widget(self, entry)
    local icon = self.app_show_icon == true
        and
        {
            widget = wibox.container.place,
            halign = self.app_name_halign,
            {
                widget = wibox.widget.imagebox,
                forced_width = self.app_icon_width,
                forced_height = self.app_icon_height,
                image = entry.icon
            }
        }
        or nil
    local name = self.app_show_name == true
        and
        {
            widget = wibox.container.place,
            halign = self.app_icon_halign,
            {
                widget = wibox.widget.textbox,
                id = "text",
                align = "center",
                font = self.app_name_font,
                markup = entry.name
            }
        }
        or nil

    local app = wibox.widget
    {
        widget = wibox.container.background,
        id = "background",
        forced_width = self.app_width,
        forced_height = self.app_height,
        shape = self.app_shape,
        bg = self.app_normal_color,
        {
            widget = wibox.container.place,
            valign = self.app_content_valign,
            {
                layout = wibox.layout.fixed.vertical,
                spacing = self.app_content_spacing,
                icon,
                name
            }
        }
    }

    function app.spawn()
        if entry.terminal == true then
            if self.terminal ~= nil then
                local terminal_command = terminal_commands_lookup[self.terminal] or self.terminal
                awful.spawn(terminal_command .. " " .. entry.executable)
            else
                awful.spawn.easy_async("gtk-launch " .. entry.executable, function(stdout, stderr)
                    if stderr then
                        awful.spawn(entry.executable)
                    end
                end)
            end
        else
            awful.spawn(entry.executable)
        end

        self:hide()
    end

    app:connect_signal("mouse::enter", function(_self)
        local widget = capi.mouse.current_wibox
        if widget then
            widget.cursor = "hand2"
        end

        local app = _self
        if app.selected then
            app:get_children_by_id("background")[1].bg = self.app_selected_hover_color
        else
            local is_opaque = color.is_opaque(self.app_normal_color)
            local is_dark = color.is_dark(self.app_normal_color)
            local app_normal_color = color.hex_to_rgba(self.app_normal_color)
            local hover_color = (is_dark or is_opaque) and
                color.rgba_to_hex(color.multiply(app_normal_color, 2.5)) or
                color.rgba_to_hex(color.multiply(app_normal_color, 0.5))
            app:get_children_by_id("background")[1].bg = self.app_normal_hover_color
        end
    end)

    app:connect_signal("mouse::leave", function(_self)
        local widget = capi.mouse.current_wibox
        if widget then
            widget.cursor = "left_ptr"
        end

        local app = _self
        if app.selected then
            app:get_children_by_id("background")[1].bg = self.app_selected_color
        else
            app:get_children_by_id("background")[1].bg = self.app_normal_color
        end
    end)

    app:connect_signal("button::press", function(_self, lx, ly, button, mods, find_widgets_result)
        if button == 1 then
            local app = _self
            if self._private.active_widget == app or not self.select_before_spawn then
                app.spawn()
            else
                -- Unmark the previous app
                unselect_app(self)

                -- Mark this app
                local pos = self._private.grid:get_widget_position(app)
                select_app(self, pos.row, pos.col)
            end
        end
    end)

    return app
end

local function search(self, text)
    unselect_app(self)

    local pos = self._private.grid:get_widget_position(self._private.active_widget)

    -- Reset all the matched entries
    self._private.matched_entries = {}
    -- Remove all the grid widgets
    self._private.grid:reset()

    if text == "" then
        self._private.matched_entries = self._private.all_entries
    else
        for index, entry in pairs(self._private.all_entries) do
            text = text:gsub( "%W", "" )

            -- Check if there's a match by the app name or app command
            if string.find(entry.name, case_insensitive_pattern(text)) ~= nil or
                self.search_commands and string.find(entry.commandline, case_insensitive_pattern(text)) ~= nil
            then
                table.insert(self._private.matched_entries, { name = entry.name, commandline = entry.commandline, executable = entry.executable, terminal = entry.terminal, icon = entry.icon })
            end
        end

        -- Sort by string similarity
        table.sort(self._private.matched_entries, function(a, b)
            return string_levenshtein(text, a.name) < string_levenshtein(text, b.name)
        end)
    end
    for index, entry in pairs(self._private.matched_entries) do
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
        if self._private.grid:get_widgets_at(pos.row, pos.col) == nil then
            local app = self._private.grid.children[#self._private.grid.children]
            pos = self._private.grid:get_widget_position(app)
        end
        select_app(self, pos.row, pos.col)
    -- Otherwise select the first app on the list
    else
        select_app(self, 1, 1)
    end
end

local function scroll_up(self)
    if #self._private.grid.children < 1 then
        self._private.active_widget = nil
        return
    end

    local rows, columns = self._private.grid:get_dimension()
    local pos = self._private.grid:get_widget_position(self._private.active_widget)
    local is_bigger_than_first_app = pos.col > 1 or pos.row > 1

    -- Check if the current marked app is not the first
    if is_bigger_than_first_app then
        unselect_app(self)
        if pos.row == 1 then
            select_app(self, rows, pos.col - 1)
        else
            select_app(self, pos.row - 1, pos.col)
        end
    -- Check if the current page is not the first
    elseif self._private.current_page > 1 then
       -- Remove the current page apps from the grid
       self._private.grid:reset()

       local max_app_index_to_include = (self._private.current_page - 1) * self._private.apps_per_page
       local min_app_index_to_include = max_app_index_to_include - self._private.apps_per_page

       for index, entry in pairs(self._private.matched_entries) do
           -- Only add widgets that are between this range (part of the current page)
           if index > min_app_index_to_include and index <= max_app_index_to_include then
               self._private.grid:add(create_app_widget(self, entry))
           end
       end

       -- If we scrolled up a page, selected app should be the last one
       rows, columns = self._private.grid:get_dimension()
       select_app(self, rows, columns)

       -- Current page should be decremented
       self._private.current_page = self._private.current_page - 1
    end
end

local function scroll_down(self)
    if #self._private.grid.children < 1 then
        self._private.active_widget = nil
        return
    end

    local rows, columns = self._private.grid:get_dimension()
    local pos = self._private.grid:get_widget_position(self._private.active_widget)
    local is_less_than_max_app = self._private.grid:index(self._private.active_widget) < #self._private.grid.children
    local is_less_than_max_page = self._private.current_page < self._private.pages_count

    -- Check if we can scroll down the app list
    if is_less_than_max_app then
        -- Unmark the previous app
        unselect_app(self)
        if pos.row == rows then
            select_app(self, 1, pos.col + 1)
        else
            select_app(self, pos.row + 1, pos.col)
        end
    -- If we can't scroll down the app list, check if we can scroll down a page
    elseif is_less_than_max_page then
        -- Remove the current page apps from the grid
        self._private.grid:reset()

        local min_app_index_to_include = self._private.apps_per_page * self._private.current_page
        local max_app_index_to_include = min_app_index_to_include + self._private.apps_per_page

        for index, entry in pairs(self._private.matched_entries) do
            -- Only add widgets that are between this range (part of the current page)
            if index > min_app_index_to_include and index <= max_app_index_to_include then
                self._private.grid:add(create_app_widget(self, entry))
            end
        end

        -- Select app 1 when scrolling to the next page
        select_app(self, 1, 1)

        -- Current page should be incremented
        self._private.current_page = self._private.current_page + 1
    end
end

local function scroll_left(self)
    if #self._private.grid.children < 1 then
        self._private.active_widget = nil
        return
    end

    local pos = self._private.grid:get_widget_position(self._private.active_widget)
    local is_bigger_than_first_column = pos.col > 1
    local is_not_first_page = self._private.current_page > 1

    -- Check if the current marked app is not the first
    if is_bigger_than_first_column then
        unselect_app(self)
        select_app(self, pos.row, pos.col - 1)
    -- Check if the current page is not the first
    elseif is_not_first_page then
       -- Remove the current page apps from the grid
       self._private.grid:reset()

       local max_app_index_to_include = (self._private.current_page - 1) * self._private.apps_per_page
       local min_app_index_to_include = max_app_index_to_include - self._private.apps_per_page

       for index, entry in pairs(self._private.matched_entries) do
           -- Only add widgets that are between this range (part of the current page)
           if index > min_app_index_to_include and index <= max_app_index_to_include then
               self._private.grid:add(create_app_widget(self, entry))
           end
       end

       -- Keep the same row from last page
       local rows, columns = self._private.grid:get_dimension()
       select_app(self, pos.row, columns)

       -- Current page should be decremented
       self._private.current_page = self._private.current_page - 1
    end
end

local function scroll_right(self)
    if #self._private.grid.children < 1 then
        self._private.active_widget = nil
        return
    end

    local rows, columns = self._private.grid:get_dimension()
    local pos = self._private.grid:get_widget_position(self._private.active_widget)
    local is_less_than_max_column = pos.col < columns
    local is_less_than_max_page = self._private.current_page < self._private.pages_count

    -- Check if we can scroll down the app list
    if is_less_than_max_column then
        -- Unmark the previous app
        unselect_app(self)

        -- Scroll up to the max app if there are directly to the right of previous app
        if self._private.grid:get_widgets_at(pos.row, pos.col + 1) == nil then
            local app = self._private.grid.children[#self._private.grid.children]
            pos = self._private.grid:get_widget_position(app)
            select_app(self, pos.row, pos.col)
        else
            select_app(self, pos.row, pos.col + 1)
        end

    -- If we can't scroll down the app list, check if we can scroll down a page
    elseif is_less_than_max_page then
        -- Remove the current page apps from the grid
        self._private.grid:reset()

        local min_app_index_to_include = self._private.apps_per_page * self._private.current_page
        local max_app_index_to_include = min_app_index_to_include + self._private.apps_per_page

        for index, entry in pairs(self._private.matched_entries) do
            -- Only add widgets that are between this range (part of the current page)
            if index > min_app_index_to_include and index <= max_app_index_to_include then
                self._private.grid:add(create_app_widget(self, entry))
            end
        end

        -- Keep the last row
        select_app(self, math.min(pos.row, #self._private.grid.children), 1)

        -- Current page should be incremented
        self._private.current_page = self._private.current_page + 1
    end
end

local function init(self)
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

    select_app(self, 1, 1)
end

--- Shows the app launcher
function app_launcher:show()
    local screen = self.screen
    if self.show_on_focused_screen then
        screen = awful.screen.focused()
    end

    screen.app_launcher = self._private.widget
    screen.app_launcher.screen = screen
    screen.app_launcher.visible = true
    self._private.prompt:run()

    local placement = self.placement
    if placement then
        local pos = placement(self.screen.app_launcher, {pretend = true})
        local animation = self.rubato
        if animation ~= nil then
            if animation.x then
                animation.x.ended:unsubscribe()
                animation.x:set(pos.x)
            else
                self._private.widget.x = pos.x
            end
            if animation.y then
                animation.y.ended:unsubscribe()
                animation.y:set(pos.y)
            else
                self._private.widget.y = pos.y
            end
        else
            self._private.widget.x = pos.x
            self._private.widget.y = pos.y
        end
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

    -- There's no other way to stop the prompt?
    root.fake_input("key_press", "Escape")
    root.fake_input("key_release", "Escape")

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
                init(self)
                screen.app_launcher.visible = false
                screen.app_launcher = nil
                animation.x.ended:unsubscribe()
            end)
        else
            animation.y.ended:subscribe(function()
                init(self)
                screen.app_launcher.visible = false
                screen.app_launcher = nil
                animation.y.ended:unsubscribe()
            end)
        end
    else
        init(self)
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

    args.terminal = args.terminal or nil
    args.search_commands = args.search_commands or true
    args.skip_names = args.skip_names or {}
    args.skip_commands = args.skip_commands or {}
    args.skip_empty_icons = args.skip_empty_icons or false
    args.sort_alphabetically = args.sort_alphabetically or true
    args.select_before_spawn = args.select_before_spawn or true
    args.hide_on_clicked_outside = args.hide_on_clicked_outside or true
    args.try_to_keep_index_after_searching = args.try_to_keep_index_after_searching or false

    args.default_app_icon_name = args.default_app_icon_name or nil
    args.default_app_icon_path = args.default_app_icon_path or nil
    args.icon_theme = args.icon_theme or nil
    args.icons_size = args.icons_size or nil

    args.show_on_focused_screen = args.show_on_focused_screen or true
    args.screen = args.screen or capi.screen.primary
    args.placement = args.placement or awful.placement.centered
    args.rubato = args.rubato or nil
    args.shirnk_width = args.shirnk_width or false
    args.shrink_height = args.shrink_height or false
    args.background = args.background or "#000000"
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

    args.apps_per_row = args.apps_per_row or 5
    args.apps_per_column = args.apps_per_column or 3
    args.apps_margin = args.apps_margin or dpi(30)
    args.apps_spacing = args.apps_spacing or dpi(30)

    args.expand_apps = args.expand_apps or true
    args.app_width = args.app_width or dpi(300)
    args.app_height = args.app_height or dpi(100)
    args.app_shape = args.app_shape or nil
    args.app_normal_color = args.app_normal_color or beautiful.bg_normal or "#000000"
    args.app_normal_hover_color = args.app_normal_hover_color or (color.is_dark(args.app_normal_color) or color.is_opaque(args.app_normal_color)) and
        color.rgba_to_hex(color.multiply(color.hex_to_rgba(args.app_normal_color), 2.5)) or
        color.rgba_to_hex(color.multiply(color.hex_to_rgba(args.app_normal_color), 0.5))
    args.app_selected_color = args.app_selected_color or beautiful.fg_normal or "#FFFFFF"
    args.app_selected_hover_color = args.app_selected_hover_color or (color.is_dark(args.app_normal_color) or color.is_opaque(args.app_normal_color)) and
        color.rgba_to_hex(color.multiply(color.hex_to_rgba(args.app_selected_color), 2.5)) or
        color.rgba_to_hex(color.multiply(color.hex_to_rgba(args.app_selected_color), 0.5))
    args.app_content_valign = args.app_content_valign or "center"
    args.app_content_spacing = args.app_content_spacing or dpi(10)
    args.app_show_icon = args.app_show_icon == nil and true or args.app_show_icon
    args.app_icon_halign = args.app_icon_halign or "center"
    args.app_icon_width = args.app_icon_width or dpi(70)
    args.app_icon_height = args.app_icon_height or dpi(70)
    args.app_show_name = args.app_show_name == nil and true or args.app_show_name
    args.app_name_halign = args.app_name_halign or "center"
    args.app_name_font = args.app_name_font or beautiful.font
    args.app_name_normal_color = args.app_name_normal_color or beautiful.fg_normal or "#FFFFFF"
    args.app_name_selected_color = args.app_name_selected_color or beautiful.bg_normal or "#000000"

    local ret = gobject({})
    ret._private = {}
    ret._private.text = ""

    gtable.crush(ret, app_launcher)
    gtable.crush(ret, args)

    -- Determines the grid width
    local grid_width = ret.shirnk_width == false
        and dpi((ret.app_width * ret.apps_per_column) + ((ret.apps_per_column - 1) * ret.apps_spacing))
        or nil
    local grid_height = ret.shrink_height == false
        and dpi((ret.app_height * ret.apps_per_row) + ((ret.apps_per_row - 1) * ret.apps_spacing))
        or nil

    -- These widgets need to be later accessed
    ret._private.prompt = awful.widget.prompt
    {
        prompt = ret.prompt_text,
        text = ret.prompt_start_text,
        font = ret.prompt_font,
        bg = ret.prompt_color,
        fg = ret.prompt_text_color,
        bg_cursor = ret.prompt_cursor_color,
        hooks =
        {
            -- Disable historyu scrolling with arrow keys
            -- TODO: implement this as other keybind? tab?
            {{}, "Up", function(command) return true, false end},
            {{}, "Down", function(command) return true, false end},
            {{}, "Return", function(command) return true, false end},
        },
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
                    ret._private.active_widget.spawn()
                end
            end
            if key == "Up" then
                scroll_up(ret)
            end
            if key == "Down" then
                scroll_down(ret)
            end
            if key == "Left" then
                scroll_left(ret)
            end
            if key == "Right" then
                scroll_right(ret)
            end
        end
    }
    ret._private.grid = wibox.widget
    {
        layout = wibox.layout.grid,
        forced_width = grid_width,
        forced_height = grid_height,
        orientation = "horizontal",
        homogeneous     = true,
        expand          = ret.expand_apps,
        spacing = ret.apps_spacing,
        forced_num_rows = ret.apps_per_row,
        buttons =
        {
            awful.button({}, 4, function() scroll_up(ret) end),
            awful.button({}, 5, function() scroll_down(ret) end)
        }
    }
    ret._private.widget = awful.popup
    {
        type = "dock",
        visible = false,
        ontop = true,
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
                                ret._private.prompt
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
    ret._private.all_entries = {}
    ret._private.matched_entries = {}
    ret._private.max_apps_per_page = ret.apps_per_column * ret.apps_per_row
    ret._private.apps_per_page = ret._private.max_apps_per_page
    ret._private.pages_count = 0
    ret._private.current_page = 1

    local app_info = Gio.AppInfo
    local apps = app_info.get_all()
    if ret.sort_alphabetically then
        table.sort(apps, function(a, b) return app_info.get_name(a):lower() < app_info.get_name(b):lower() end)
    end

    local icon_theme = require(tostring(path):match(".*bling") .. ".helpers.icon_theme")(ret.icon_theme, ret.icon_size)

    for _, app in ipairs(apps) do
        if app.should_show(app) then
            local name = app_info.get_name(app)
            local commandline = app_info.get_commandline(app)
            local executable = app_info.get_executable(app)
            local icon = icon_theme:get_gicon_path(app_info.get_icon(app))

            -- Check if this app should be skipped, depanding on the skip_names / skip_commands table
            if not has_value(ret.skip_names, name) and not has_value(ret.skip_commands, commandline) then
                -- Check if this app should be skipped becuase it's iconless depanding on skip_empty_icons
                if icon ~= "" or ret.skip_empty_icons == false then
                    if icon == "" then
                        if ret.default_app_icon_name ~= nil then
                            icon = icon_theme:get_icon_path(ret.default_app_icon_name)
                        elseif ret.default_app_icon_path ~= nil then
                            icon = ret.default_app_icon_path
                        else
                            icon = icon_theme:choose_icon({ "application-all", "application", "application-default-icon", "app" })
                        end
                    end

                    local desktop_app_info = Gio.DesktopAppInfo.new(app_info.get_id(app))
                    local terminal = Gio.DesktopAppInfo.get_string(desktop_app_info, "Terminal") == "true" and true or false
                    table.insert(ret._private.all_entries, { name = name, commandline = commandline, executable = executable, terminal = terminal, icon = icon })
                end
            end
        end
    end

    init(ret)

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

    if ret.hide_on_clicked_outside then
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

    return ret
end

function app_launcher.mt:__call(...)
    return new(...)
end

return setmetatable(app_launcher, app_launcher.mt)
