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
    end
end

local function unmark_app(self, index)
    local app = self._private.grid.children[index]
    if app ~= nil then
        app:get_children_by_id("background")[1].bg = self.app_normal_color
    end
end

local function create_app_widget(self, name, cmdline, icon, index)
    return wibox.widget
    {
        widget = wibox.container.background,
        id = "background",
        shape = gears.shape.rounded_rect,
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

                    -- Mark the next app
                    mark_app(self, self._private.current_index)
                end
            end),
        },
        {
            layout = wibox.layout.fixed.vertical,
            forced_width = dpi(200),
            forced_height = dpi(100),
            {
                layout = wibox.layout.align.horizontal,
                expand = "outside",
                nil,
                {
                    widget = wibox.widget.imagebox,
                    forced_width = dpi(70),
                    forced_height = dpi(70),
                    image = icon
                },
                nil
            },
            {
                widget = wibox.widget.textbox,
                id = "text",
                font = beautiful.font,
                align = "center",
                markup = name
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

    for index, entry in pairs(self._private.all_entries) do
        text = text:gsub( "%W", "" )

        -- Check if there's a match by the app name or app command
        if string.find(entry.name, case_insensitive_pattern(text)) ~= nil or
            self.search_commands and string.find(entry.cmdline, case_insensitive_pattern(text)) ~= nil
        then
            table.insert(self._private.matched_entries, #self._private.matched_entries + 1, { name = entry.name, cmdline = entry.cmdline, icon = entry.icon })
            self._private.grid:add(create_app_widget(self, entry.name, entry.cmdline, entry.icon, #self._private.matched_entries))
        end
    end

    -- Recalculate the apps per page based on the current matched entries
    self._private.apps_per_page = math.min(#self._private.matched_entries, self.forced_num_cols * self.forced_num_rows)

    -- Recalculate the apps per page based on the current pages count
    self._private.pages_count = math.ceil(math.max(1, #self._private.matched_entries) / math.max(1, self._private.apps_per_page))

    -- If there's only 1 page, apps on last page is the same as apps per page
    if self._private.pages_count <=1 then
        self._private.apps_on_last_page = self._private.apps_per_page

    -- Otherwise recalculate the apps on last page
    else
        self._private.apps_on_last_page = #self._private.matched_entries % self._private.apps_per_page
    end

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

local function run_prompt(self)
    awful.prompt.run
    {
        prompt = self.prompt_text,
        bg_cursor = self.prompt_cursor_bg,
        textbox = self._private.shell.widget,
        text = self.prompt_start_text,
        changed_callback = function(text)
            search(self, text)
        end,
        keypressed_callback = function(mod, key, cmd)
            if key == "Return" then
                self._private.grid.children[self._private.current_index].spawn()
            end
        end,
        done_callback = function()
            self:hide()
        end
    }
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

        local widgets_count = 0
        for index, entry in pairs(self._private.matched_entries) do
            -- Only add widgets that are between this range (part of the current page)
            if index > min_app_index_to_include and index <= max_app_index_to_include then
                widgets_count = widgets_count + 1
                self._private.grid:add(create_app_widget(self, entry.name, entry.cmdline, entry.icon, widgets_count))
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
    local is_less_than_max_app = self._private.current_index < self._private.apps_per_page
    local is_less_than_max_page = self._private.current_page < self._private.pages_count
    local can_scroll_less_than_max_page = is_less_than_max_app and is_less_than_max_page

    local max_page_is_less_than_max_app = self._private.current_index < self._private.apps_on_last_page
    local is_max_page = self._private.current_page == self._private.pages_count
    local can_scroll_max_page = max_page_is_less_than_max_app and is_max_page

    local can_switch_to_next_page = self._private.current_page < self._private.pages_count

    -- Check if we can scroll down the app list
    if can_scroll_less_than_max_page or can_scroll_max_page then
        -- Unmark the previous app
        unmark_app(self, self._private.current_index)

        -- Current index should be incremented
        self._private.current_index = self._private.current_index + 1

        -- Mark the new app
        mark_app(self, self._private.current_index)

    -- If we can't scroll down the app list, check if we can scroll down a page
    elseif can_switch_to_next_page then
        -- Remove the current page apps from the grid
        self._private.grid:reset()

        local min_app_index_to_include = self._private.current_index * self._private.current_page
        local max_app_index_to_include = min_app_index_to_include + self._private.apps_per_page

        local widgets_count = 0
        for index, entry in pairs(self._private.matched_entries) do
            -- Only add widgets that are between this range (part of the current page)
            if index > min_app_index_to_include and index <= max_app_index_to_include then
                widgets_count = widgets_count + 1
                self._private.grid:add(create_app_widget(self, entry.name, entry.cmdline, entry.icon, widgets_count))
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
    self.screen.app_launcher.placement = args.placement or self.placement
    self.screen.app_launcher.visible = true
    run_prompt(self)
    self:emit_signal("bling::app_launcher::visibility", true)
end

--- Hides the app launcher
function app_launcher:hide(args)
    local args = args or {}

    -- There's no other way to stop the prompt?
    root.fake_input('key_press', "Escape")
    root.fake_input('key_release', "Escape")

    self.screen = args.screen or self.screen
    self.screen.app_launcher.visible = false
    self.screen.app_launcher = {}

    -- Reset back to initial values
    self._private.apps_per_page = self.forced_num_cols * self.forced_num_rows
    self._private.apps_on_last_page = #self._private.all_entries % self._private.apps_per_page
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

-- Returns a new app launc` her
local function new(args)
    args = args or {}

    args.select_before_spawn = args.select_before_spawn or true
    args.try_to_keep_index_after_searching = args.try_to_keep_index_after_searching or false

    args.background = args.background or "#000000"
    args.screen = args.screen or screen.primary
    args.placement = args.placement or awful.placement.centered
    args.shape = args.shape or nil
    args.app_normal_color = args.app_normal_color or beautiful.bg_normal or "#808080"
    args.app_selected_color = args.app_selected_color or beautiful.fg_normal or "#FF0000"
    args.grid_margin = args.grid_margin or dpi(30)
    args.grid_spacing = args.grid_spacing or dpi(30)
    args.item_width = args.item_width or dpi(200)
    args.forced_num_rows = args.forced_num_rows or 3
    args.forced_num_cols = args.forced_num_cols or 5
    args.prompt_text = args.prompt_text or "<b>Search</b>: "
    args.prompt_cursor_bg = args.prompt_cursor_bg or beautiful.fg_normal
    args.prompt_start_text = args.prompt_start_text or ""
    args.search_commands = args.search_commands or true
    args.skip_names = args.skip_names or {}
    args.skip_commands = args.skip_commands or {}
    args.skip_empty_icons = args.skip_empty_icons or false
    args.sort_alphabetically = args.sort_alphabetically or true

    local ret = gears.object({})
    ret._private = {}

    gtable.crush(ret, app_launcher)
    gtable.crush(ret, args)

    -- Determines the grid width
    ret._private.grid_width = dpi(ret.item_width * ret.forced_num_cols + ret.grid_margin + ret.grid_spacing)

    -- These widgets need to be later accessed
    ret._private.shell = awful.widget.prompt
    {
        bg = "#00000000",
        fg = beautiful.xcolor0,
        font = beautiful.font_name .. "Bold 15"
    }
    ret._private.grid = wibox.widget
    {
        layout = wibox.layout.grid,
        orientation = "horizontal",
        forced_num_rows = ret.forced_num_rows,
        homogeneous     = true,
        expand          = false,
        forced_width = ret._private.grid_width,
        spacing = dpi(30),
        buttons =
        {
            -- Scroll up
            awful.button({}, 4, function() scroll_up(ret) end),
            -- Scroll down
            awful.button({}, 5, function() scroll_down(ret) end)
        }
    }
    ret._private.widget = awful.popup
    ({
        type = "dock",
        visible = false,
        ontop = true,
        shape = ret.shape,
        bg =  ret.background,
        widget =
        {
            layout = wibox.layout.fixed.vertical,
            {
                widget = wibox.container.background,
                forced_height = dpi(100),
                bg = beautiful.xcolor1,
                {
                    widget = wibox.container.margin,
                    left = dpi(15),
                    ret._private.shell
                }
            },
            {
                widget = wibox.container.margin,
                margins = dpi(30),
                ret._private.grid
            }
        }
    })

    -- Private variables to be used to be used by the scrolling and searching functions
    ret._private.all_entries = {}
    ret._private.matched_entries = {}
    ret._private.apps_per_page = ret.forced_num_cols * ret.forced_num_rows
    ret._private.apps_on_last_page = 0
    ret._private.pages_count = 0
    ret._private.current_index = 1
    ret._private.current_page = 1

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
                    -- Insert a table containing the name, command and icon of the app into the all_entries table
                    table.insert(ret._private.all_entries, #ret._private.all_entries + 1, { name = entry.name, cmdline = entry.cmdline, icon = entry.icon })

                    -- Only add the app widgets that are part of the first page
                    if index <= ret._private.apps_per_page then
                        ret._private.grid:add(create_app_widget(ret, entry.name, entry.cmdline, entry.icon, index))
                    end
                end
            end
        end

        -- Matched entries contains all the apps initially
        ret._private.matched_entries = ret._private.all_entries

        ret._private.apps_on_last_page = #ret._private.all_entries % ret._private.apps_per_page
        ret._private.pages_count = math.ceil(#ret._private.all_entries / ret._private.apps_per_page)

        -- Mark the first app on startup
        mark_app(ret, 1)
    end)

    return ret
end

function app_launcher.mt:__call(...)
    return new(...)
end

return setmetatable(app_launcher, app_launcher.mt)
