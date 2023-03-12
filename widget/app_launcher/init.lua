local Gio = require("lgi").Gio
local awful = require("awful")
local gobject = require("gears.object")
local gtable = require("gears.table")
local gtimer = require("gears.timer")
local wibox = require("wibox")
local beautiful = require("beautiful")
local text_input_widget = require(... .. ".text_input")
local rofi_grid_widget = require(... .. ".rofi_grid")
local dpi = beautiful.xresources.apply_dpi
local string = string
local table = table
local math = math
local ipairs = ipairs
local capi = { screen = screen, mouse = mouse }
local path = ...
local helpers = require(tostring(path):match(".*bling") .. ".helpers")

local app_launcher  = { mt = {} }

local AWESOME_SENSIBLE_TERMINAL_SCRIPT_PATH = debug.getinfo(1).source:match("@?(.*/)") .. "awesome-sensible-terminal"
local RUN_AS_ROOT_SCRIPT_PATH = debug.getinfo(1).source:match("@?(.*/)") .. "run-as-root.sh"

local function default_value(value, default)
    if value == nil then
        return default
    else
        return value
    end
end

local function has_value(tab, val)
    for _, value in ipairs(tab) do
        if val:lower():find(value:lower(), 1, true) then
            return true
        end
    end
    return false
end

local function build_widget(self)
    local widget_template = self.widget_template
    if widget_template == nil then
        widget_template = wibox.widget
        {
            layout = rofi_grid_widget,
            lazy_load_widgets = false,
            widget_template = wibox.widget {
                widget = wibox.container.margin,
                margins = dpi(15),
                {
                    layout = wibox.layout.fixed.vertical,
                    spacing = dpi(15),
                    {
                        widget = text_input_widget,
                        id = "text_input_role",
                        forced_width = dpi(650),
                        forced_height = dpi(60),
                        text_color = self.text_input_color,
                        reset_on_stop = self.reset_on_hide,
                        placeholder = self.text_input_placeholder,
                        unfocus_keys = { },
                        unfocus_on_clicked_inside = false,
                        unfocus_on_clicked_outside = false,
                        unfocus_on_mouse_leave = false,
                        unfocus_on_tag_change = false,
                        unfocus_on_other_text_input_focus = false,
                        focus_on_subject_mouse_enter = nil,
                        unfocus_on_subject_mouse_leave = nil,
                        widget_template = wibox.widget {
                            widget = wibox.container.background,
                            bg = self.text_input_bg_color,
                            {
                                widget = wibox.container.margin,
                                margins = dpi(15),
                                {
                                    layout = wibox.layout.stack,
                                    {
                                        widget = wibox.widget.textbox,
                                        id = "placeholder_role",
                                        text = "Search: "
                                    },
                                    {
                                        widget = wibox.widget.textbox,
                                        id = "text_role"
                                    },
                                }
                            }
                        }
                    },
                    {
                        layout = wibox.layout.fixed.horizontal,
                        spacing = dpi(10),
                        {
                            layout = wibox.layout.grid,
                            id = "grid_role",
                            orientation = "horizontal",
                            homogeneous = true,
                            spacing = dpi(15),
                            forced_num_cols = self.apps_per_column,
                            forced_num_rows = self.apps_per_row,
                        },
                        {
                            layout = wibox.container.rotate,
                            direction = 'west',
                            {
                                widget = wibox.widget.slider,
                                id = "scrollbar_role",
                                forced_width = dpi(5),
                                forced_height = dpi(10),
                                minimum = 1,
                                value = 1,
                                bar_height= 3,
                                bar_color = "#00000000",
                                bar_active_color = "#00000000",
                                handle_width = dpi(50),
                                handle_color = beautiful.bg_normal,
                                handle_color = beautiful.fg_normal
                            }
                        }
                    }
                }
            },
            entry_template = function(app)
                local widget = wibox.widget
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

                widget:connect_signal("button::press", function(_, __, __, button)
                    if button == 1 then
                        print(app:is_selected())
                        if app:is_selected() or not self.select_before_spawn then
                            app:run()
                        else
                            app:select()
                        end
                    end
                end)

                widget:connect_signal("select", function()
                    widget.bg = self.app_selected_color
                    local name_widget = widget:get_children_by_id("name_role")[1]
                    name_widget.markup = string.format("<span foreground='%s'>%s</span>", self.app_name_selected_color, name_widget.text)
                end)

                widget:connect_signal("unselect", function()
                    widget.bg = self.app_normal_color
                    local name_widget = widget:get_children_by_id("name_role")[1]
                    name_widget.markup = string.format("<span foreground='%s'>%s</span>", self.app_name_normal_color, name_widget.text)
                end)

                return widget
            end
        }
    end
    widget_template:set_search_fn(function(text, app)
        local matched_apps = Gio.DesktopAppInfo.search(text:lower())
        for _, matched_app in ipairs(matched_apps) do
            for _, app_id in ipairs(matched_app) do
                if app.id == app_id then
                    return true
                end
            end
        end
    end)

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
        widget = widget_template
    }

    self:get_text_input():connect_signal("key::press", function(_, mod, key, cmd)
        if key == "Escape" then
            self:hide()
        end
    end)

    self:get_text_input():connect_signal("key::release", function(_, mod, key, cmd)
        if key == "Return" then
            if self:get_rofi_grid():get_selected_widget() ~= nil then
                self:get_rofi_grid():get_selected_widget():run()
            end
        end
    end)
end

local function default_sort_fn(self, a, b)
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
end

local function generate_apps(self)
    local entries = {}

    local app_launcher = self

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

                    local app = {
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
                        launch = function()
                            app:launch()
                        end
                    }

                    function app:run()
                        if self.terminal == true then
                            local pid = awful.spawn.with_shell(AWESOME_SENSIBLE_TERMINAL_SCRIPT_PATH .. " -e " .. self.exec)
                            local class = self.startup_wm_class or self.name
                            awful.spawn.with_shell(string.format(
                                [[xdotool search --sync --all --pid %s --name '.*' set_window --classname "%s" set_window --class "%s"]],
                                pid,
                                class,
                                class
                            ))
                        else
                            self:launch()
                        end

                        if app_launcher.hide_on_launch then
                            app_launcher:hide()
                        end
                    end

                    function app:run_or_select()
                        if self:is_selected() then
                            self:run()
                        else
                            self:select()
                        end
                    end

                    function app:run_as_root()
                        if self.terminal == true then
                            local pid = awful.spawn.with_shell(
                                AWESOME_SENSIBLE_TERMINAL_SCRIPT_PATH .. " -e " ..
                                RUN_AS_ROOT_SCRIPT_PATH .. " " ..
                                self.exec
                            )
                            local class = self.startup_wm_class or self.name
                            awful.spawn.with_shell(string.format(
                                [[xdotool search --sync --all --pid %s --name '.*' set_window --classname "%s" set_window --class "%s"]],
                                pid,
                                class,
                                class
                            ))
                        else
                            awful.spawn(RUN_AS_ROOT_SCRIPT_PATH .. " " .. self.exec)
                        end

                        if app_launcher.hide_on_launch then
                            app_launcher:hide()
                        end
                    end

                    table.insert(entries, app)
                end
            end
        end
    end

    self:get_rofi_grid():set_entries(entries, self.sort_fn)
end

function app_launcher:set_favorites(favorites)
    self.favorites = favorites
    self:get_rofi_grid():set_sort_fn(self.sort_fn)
    self:refresh()
end

function app_launcher:show()
    if self.show_on_focused_screen then
        self:get_widget().screen = awful.screen.focused()
    end

    self:get_widget().visible = true
    self:get_text_input():focus()
    self:emit_signal("visibility", true)
end

function app_launcher:hide()
    if self:get_widget().visible == false then
        return
    end

    if self.reset_on_hide == true then
        self:get_rofi_grid():reset()
    end

    self:get_widget().visible = false
    self:get_text_input():unfocus()
    self:emit_signal("visibility", false)
end

function app_launcher:toggle()
    if self:get_widget().visible then
        self:hide()
    else
        self:show()
    end
end

function app_launcher:get_widget()
    return self._private.widget
end

function app_launcher:get_rofi_grid()
    return self:get_widget().widget
end

function app_launcher:get_text_input()
    return self:get_rofi_grid():get_text_input()
end

local function new(args)
    args = args or {}

    local ret = gobject {}

    args.sort_fn = default_value(args.sort_fn, function(a, b)
        return default_sort_fn(ret, a, b)
    end)
    args.sort_alphabetically = default_value(args.sort_alphabetically, true)
    args.reverse_sort_alphabetically = default_value(args.reverse_sort_alphabetically, false)
    args.favorites = default_value(args.favorites, {})
    args.skip_names = default_value(args.skip_names, {})
    args.skip_commands = default_value(args.skip_commands, {})
    args.skip_empty_icons = default_value(args.skip_empty_icons, false)
    args.select_before_spawn = default_value(args.select_before_spawn, true)
    args.hide_on_left_clicked_outside = default_value(args.hide_on_left_clicked_outside, true)
    args.hide_on_right_clicked_outside = default_value(args.hide_on_right_clicked_outside, true)
    args.hide_on_launch = default_value(args.hide_on_launch, true)
    args.reset_on_hide = default_value(args.reset_on_hide, true)

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

    args.text_input_bg_color = default_value(args.text_input_bg_color, "#000000")
    args.text_input_color = default_value(args.text_input_color, "#FFFFFF")
    args.text_input_placeholder = default_value(args.text_input_placeholder, "Search: ")

    args.app_normal_color = default_value(args.app_normal_color, "#000000")
    args.app_selected_color = default_value(args.app_selected_color, "#FFFFFF")
    args.app_name_normal_color = default_value(args.app_name_normal_color, "#FFFFFF")
    args.app_name_selected_color = default_value(args.app_name_selected_color, "#000000")

    gtable.crush(ret, app_launcher, true)
    gtable.crush(ret, args, true)

    ret._private = {}
    ret._private.text = ""
    ret._private.pages_count = 0
    ret._private.current_page = 1
    ret._private.search_timer = gtimer {
        timeout = 0.05,
        call_now = false,
        autostart = false,
        single_shot = true,
        callback = function()
            ret:search()
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

    awful.spawn.easy_async_with_shell("pkill -f 'inotifywait -m /usr/share/applications -e modify'", function()
        awful.spawn.with_line_callback("inotifywait -m /usr/share/applications -e modify", {stdout = function()
            generate_apps(ret)
        end})
    end)

    build_widget(ret)
    generate_apps(ret)

    return ret
end

function app_launcher.mt:__call(...)
    return new(...)
end

return setmetatable(app_launcher, app_launcher.mt)
