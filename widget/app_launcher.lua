local awful = require("awful")
local gears = require("gears")
local gtable = require("gears.table")
local wibox = require("wibox")
local beautiful = require("beautiful")
local menu_gen   = require("menubar.menu_gen")
local dpi = beautiful.xresources.apply_dpi

local string = string
local table = table
local math = math
local pairs = pairs
local root = root

local app_launcher  = { mt = {} }

local function mark_app(self, index)
    local app = self._private.grid.children[index]
    if app ~= nil then
        app:get_children_by_id("background")[1].bg = self.app_selected_color
        local text_widget = app:get_children_by_id("text")[1]
        if text_widget ~= nil then
            text_widget.markup = "<span foreground='" .. self.app_name_selected_color .. "'>" .. text_widget.text .. "</span>"
        end
    end
end

local function unmark_app(self, index)
    local app = self._private.grid.children[index]
    if app ~= nil then
        app:get_children_by_id("background")[1].bg = self.app_normal_color
        local text_widget = app:get_children_by_id("text")[1]
        if text_widget ~= nil then
            text_widget.markup = "<span foreground='" .. self.app_name_normal_color .. "'>" .. text_widget.text .. "</span>"
        end
    end
end

local function create_app_widget(self, name, cmdline, icon, index)
    local icon = self.app_show_icon == true
        and
        {
            widget = wibox.container.place,
            halign = self.app_name_halign,
            {
                widget = wibox.widget.imagebox,
                forced_width = self.app_icon_width,
                forced_height = self.app_icon_height,
                image = icon
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
                markup = name
            }
        }
        or nil

    return wibox.widget
    {
        widget = wibox.container.background,
        id = "background",
        forced_width = self.app_width,
        forced_height = self.app_height,
        shape = self.app_shape,
        bg = self.app_normal_color,
        spawn = function() awful.spawn(cmdline) end,
        buttons =
        {
            awful.button({}, 1, function()
                if index == self._private.current_index or not self.select_before_spawn then
                    awful.spawn(cmdline)
                    self:hide()
                else
                    -- Unmark the previous app
                    unmark_app(self, self._private.current_index)

                    self._private.current_index = index

                    -- Mark this app
                    mark_app(self, self._private.current_index)
                end
            end),
        },
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

local function search(self, text)
    -- Reset all the matched entries
    self._private.matched_entries = {}
    -- Remove all the grid widgets
    self._private.grid:reset()

    collectgarbage("collect")

    for index, entry in pairs(self._private.all_entries) do
        text = text:gsub( "%W", "" )

        -- Check if there's a match by the app name or app command
        if string.find(entry.name, case_insensitive_pattern(text)) ~= nil or
            self.search_commands and string.find(entry.cmdline, case_insensitive_pattern(text)) ~= nil
        then
            table.insert(self._private.matched_entries, #self._private.matched_entries + 1, { name = entry.name, cmdline = entry.cmdline, icon = entry.icon })

            -- Only add the widgets for apps that are part of the first page
            if #self._private.grid.children + 1 <= self._private.max_apps_per_page then
                self._private.grid:add(create_app_widget(self, entry.name, entry.cmdline, entry.icon,  #self._private.grid.children + 1))
            end
        end
    end

    -- Recalculate the apps per page based on the current matched entries
    self._private.apps_per_page = math.min(#self._private.matched_entries, self._private.max_apps_per_page)

    -- Recalculate the pages count based on the current apps per page
    self._private.pages_count = math.ceil(math.max(1, #self._private.matched_entries) / math.max(1, self._private.apps_per_page))

    -- This is an option to mimic rofi behaviour where after a search
    -- it will reselect the app whose index is the same as the app index that was previously selected
    -- and if matched_entries.length < current_index it will instead select the app with the greatest index
    if self.try_to_keep_index_after_searching then
        self._private.current_index = math.max(math.min(self._private.current_index, #self._private.matched_entries), 1)

    -- Otherwise select the first app on the list
    else
        self._private.current_index = 1
    end
    self._private.current_page = 1

    mark_app(self, self._private.current_index)
end

local function scroll_up(self)
    -- Check if the current marked app is not the first
    if self._private.current_index > 1 then
        unmark_app(self, self._private.current_index)

        -- Current index should be decremented
        self._private.current_index = self._private.current_index - 1

        -- Mark the new app
        mark_app(self, self._private.current_index)

    -- Check if the current page is not the first
    elseif self._private.current_page > 1 then
        -- Remove the current page apps from the grid
        self._private.grid:reset()

        local max_app_index_to_include = (self._private.current_page - 1) * self._private.apps_per_page
        local min_app_index_to_include = max_app_index_to_include - self._private.apps_per_page


        for index, entry in pairs(self._private.matched_entries) do
            -- Only add widgets that are between this range (part of the current page)
            if index > min_app_index_to_include and index <= max_app_index_to_include then
                self._private.grid:add(create_app_widget(self, entry.name, entry.cmdline, entry.icon, #self._private.grid.children + 1))
            end
        end

        -- If we scrolled up a page, selected app should be the last one
        self._private.current_index = self._private.apps_per_page
        mark_app(self, self._private.current_index)

        -- Current page should be decremented
        self._private.current_page = self._private.current_page - 1
    end
end

local function scroll_down(self)
    local is_less_than_max_app = self._private.current_index < #self._private.grid.children
    local is_less_than_max_page = self._private.current_page < self._private.pages_count

    -- Check if we can scroll down the app list
    if is_less_than_max_app then
        -- Unmark the previous app
        unmark_app(self, self._private.current_index)

        -- Current index should be incremented
        self._private.current_index = self._private.current_index + 1

        -- Mark the new app
        mark_app(self, self._private.current_index)

    -- If we can't scroll down the app list, check if we can scroll down a page
    elseif is_less_than_max_page then
        -- Remove the current page apps from the grid
        self._private.grid:reset()

        local min_app_index_to_include = self._private.current_index * self._private.current_page
        local max_app_index_to_include = min_app_index_to_include + self._private.apps_per_page

        for index, entry in pairs(self._private.matched_entries) do
            -- Only add widgets that are between this range (part of the current page)
            if index > min_app_index_to_include and index <= max_app_index_to_include then
                self._private.grid:add(create_app_widget(self, entry.name, entry.cmdline, entry.icon, #self._private.grid.children + 1))
            end
        end

        -- Current app is 1 if we scroll to the next page
        self._private.current_index = 1
        mark_app(self, self._private.current_index)

        -- Current page should be incremented
        self._private.current_page = self._private.current_page + 1
    end
end

--- Shows the app launcher
function app_launcher:show(args)
    local args = args or {}

    self.screen = args.screen or self.screen
    self.screen.app_launcher = self._private.widget
    self.screen.app_launcher.screen = self.screen
    self.screen.app_launcher.visible = true
    self._private.prompt:run()

    local x = args.x or self.x or nil
    if self.rubato and self.rubato.x and x then
        self.rubato.x:set(x)
    elseif x then
        self.screen.app_launcher.x = x
    end

    local y = args.y or self.y or nil
    if self.rubato and self.rubato.y and y then
        self.rubato.y:set(y)
    elseif y then
        self.screen.app_launcher.y = y
    end

    local placement = args.placement or self.placement or nil
    if placement then
        self.screen.app_launcher.placement = placement
    end

    self:emit_signal("bling::app_launcher::visibility", true)
end

--- Hides the app launcher
function app_launcher:hide(args)
    local args = args or {}

    -- There's no other way to stop the prompt?
    root.fake_input('key_press', "Escape")
    root.fake_input('key_release', "Escape")

    if self.rubato and self.rubato.x then
        self.rubato.x:set(self.rubato.x:initial())
        self.rubato.x.ended:subscribe(function()
            self.screen.app_launcher.visible = false
        end)
    end

    if self.rubato and self.rubato.y then
        self.rubato.y:set(self.rubato.y:initial())
        self.rubato.y.ended:subscribe(function()
            self.screen.app_launcher.visible = false
        end)
    end

    if not self.rubato then
        self.screen.app_launcher.visible = false
    end

    self.screen = args.screen or self.screen
    self.screen.app_launcher = {}

    -- Reset back to initial values
    self._private.apps_per_page = self._private.max_apps_per_page
    self._private.pages_count = math.ceil(#self._private.all_entries / self._private.apps_per_page)
    self._private.matched_entries = self._private.all_entries
    self._private.current_index = 1
    self._private.current_page = 1
    self._private.grid:reset()

    -- Add the app widgets for the next time
    for index, entry in pairs(self._private.all_entries) do
        -- Only add the apps that are part of the first page
        if index <= self._private.apps_per_page then
            self._private.grid:add(create_app_widget(self, entry.name, entry.cmdline, entry.icon, index))
        else
            break
        end
    end

    -- Select the first app for the next time
    mark_app(self, self._private.current_index)

    self:emit_signal("bling::app_launcher::visibility", false)
end

--- Toggles the app launcher
function app_launcher:toggle(args)
    local args = args or {}

    self.screen = args.screen or self.screen
    if self.screen.app_launcher and self.screen.app_launcher.visible then
        self:hide(self.screen)
    else
        self:show(self.screen)
    end
end

-- Returns a new app launcher
local function new(args)
    args = args or {}

    args.search_commands = args.search_commands or true
    args.skip_names = args.skip_names or {}
    args.skip_commands = args.skip_commands or {}
    args.skip_empty_icons = args.skip_empty_icons or false
    args.sort_alphabetically = args.sort_alphabetically or true
    args.select_before_spawn = args.select_before_spawn or true
    args.try_to_keep_index_after_searching = args.try_to_keep_index_after_searching or false
    args.default_app_icon = args.default_app_icon or nil

    args.rubato = args.rubato or nil
    args.shirnk_width = args.shirnk_width or false
    args.shrink_height = args.shrink_height or false
    args.background = args.background or "#000000"
    args.screen = args.screen or screen.primary
    args.x = args.x or nil
    args.y = args.y or nil
    args.placement = args.placement or (args.x == nil and args.y == nil) and awful.placement.centered or nil
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
    args.app_selected_color = args.app_selected_color or beautiful.fg_normal or "#FFFFFF"
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

    local ret = gears.object({})
    ret._private = {}

    gtable.crush(ret, app_launcher)
    gtable.crush(ret, args)

    -- Determines the grid width
    local grid_width =  ret.shirnk_width == false
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
        changed_callback = function(text)
            search(ret, text)
        end,
        keypressed_callback = function(mod, key, cmd)
            if key == "Return" then
                ret._private.grid.children[ret._private.current_index].spawn()
            end
        end,
        done_callback = function()
            ret:hide()
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
    ret._private.apps_per_page = ret.apps_per_column * ret.apps_per_row
    ret._private.max_apps_per_page = ret._private.apps_per_page
    ret._private.pages_count = 0
    ret._private.current_index = 1
    ret._private.current_page = 1

    -- Delay to prevent the app list from being empty on some occasions
    gears.timer.delayed_call(function()
        menu_gen.generate(function(entries)
            -- Sort the table alphabetically
            if ret.sort_alphabetically then
                table.sort(entries, function(a, b) return a.name:lower() < b.name:lower() end)
            end

            -- Loop over the app entries
            for index, entry in pairs(entries) do
                -- Check if this app should be skipped, depanding on the skip_names / skip_commands table
                if not has_value(ret.skip_names, entry.name) and not has_value(ret.skip_commands, entry.cmdline) then
                    -- Check if this app should be skipped becuase it's iconless depanding on skip_empty_icons
                    if entry.icon ~= nil or ret.skip_empty_icons == false then
                        if entry.icon == nil then
                            entry.icon = ret.default_app_icon
                        end

                        -- Insert a table containing the name, command and icon of the app into the all_entries table
                        table.insert(ret._private.all_entries, #ret._private.all_entries + 1, { name = entry.name, cmdline = entry.cmdline, icon = entry.icon })

                        -- Only add the app widgets that are part of the first page
                        if #ret._private.all_entries <= ret._private.apps_per_page then
                            ret._private.grid:add(create_app_widget(ret, entry.name, entry.cmdline, entry.icon, #ret._private.all_entries))
                        end
                    end
                end
            end

            -- Matched entries contains all the apps initially
            ret._private.matched_entries = ret._private.all_entries
            ret._private.pages_count = math.ceil(#ret._private.all_entries / ret._private.apps_per_page)

            -- Mark the first app on startup
            mark_app(ret, 1)
        end)
    end)

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

    return ret
end

function app_launcher.mt:__call(...)
    return new(...)
end

return setmetatable(app_launcher, app_launcher.mt)
