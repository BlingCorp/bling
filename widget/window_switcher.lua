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

local get_num_clients = function(s)
    local minimized_clients_in_tag = 0
    local matcher = function (c)
        return awful.rules.match(c, { minimized = true, skip_taskbar = false, hidden = false, first_tag = s.selected_tag })
    end
    for c in awful.client.iterate(matcher) do
        minimized_clients_in_tag = minimized_clients_in_tag + 1
    end
    return minimized_clients_in_tag + #s.clients
end

local window_switcher_hide = function()
    -- Add currently focused client to history
    if client.focus then
        local window_switcher_last_client = client.focus
        awful.client.focus.history.add(window_switcher_last_client)
        -- Raise client that was focused originally
        -- Then raise last focused client
        if window_switcher_first_client and window_switcher_first_client.valid then
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
    s.window_switcher_box.visible = false
end

local function draw_widget(s, type, background, border_width, border_radius, border_color, clients_spacing, client_icon_horizontal_spacing, client_width, client_height, client_margins, thumbnail_margins, name_scroll_step_function, name_scroll_speed, name_valign, name_forced_width, name_font, icon_valign, icon_width, custom_icons, font_icons, font_icons_font, mouse_keys)
    local set_font_icon = function(self, c)
        local i = font_icons[c.class] or font_icons["_"]
        self:get_children_by_id("text_icon")[1].markup = "<span foreground='" .. i.color .. "'>" .. i.symbol .. "</span>"
    end

    local set_custom_icon = function(self, c)
        local i = custom_icons[c.class] or custom_icons["_"]
        self:get_children_by_id("custom_icon")[1].image = i.icon
    end

    local update_thumbnail = function(self, c)
        local content = gears.surface(c.content)
        local cr = cairo.Context(content)
        local x, y, w, h = cr:clip_extents()
        local img = cairo.ImageSurface.create(cairo.Format.ARGB32, w - x, h - y)
        cr = cairo.Context(img)
        cr:set_source_surface(content, 0, 0)
        cr.operator = cairo.Operator.SOURCE
        cr:paint()
        self:get_children_by_id("thumbnail")[1].image = gears.surface.load(img)
    end

    local icon_widget = function()
        if (font_icons) ~= nil then
            return {
                font = font_icons_font,
                forced_width = icon_width,
                valign = icon_valign,
                id = "text_icon",
                widget = wibox.widget.textbox
            }
        elseif (custom_icons) ~= nil then
            return {
                forced_width = icon_width,
                valign = icon_valign,
                id = 'custom_icon',
                widget = wibox.widget.imagebox
            }
        end

        return {
            awful.widget.clienticon,
            forced_width = icon_width,
            valign = icon_valign,
            widget = wibox.container.place
        }
    end

    local tasklist_widget = function()
        if type == "thumbnail" then
            return awful.widget.tasklist {
                screen = s,
                filter = awful.widget.tasklist.filter.currenttags,
                buttons = mouse_keys,
                style = { font = name_font },
                layout = { layout  = wibox.layout.flex.horizontal, spacing = clients_spacing },
                widget_template =
                {
                    widget = wibox.container.background,
                    id = "bg_role",
                    forced_width = client_width,
                    forced_height = client_height,
                    create_callback = function(self, c, _, __)
                        if (font_icons) ~= nil then
                            set_font_icon(self, c)
                            c:connect_signal("property::class", function() set_font_icon(self, c) end)
                        elseif (custom_icons) ~= nil then
                            set_custom_icon(self, c)
                            c:connect_signal("property::class", function() set_custom_icon(self, c) end)
                        end
                        update_thumbnail(self, c)
                    end,
                    update_callback = function(self, c, _, __)
                        update_thumbnail(self, c)
                    end,
                    {
                        {
                            {
                                horizontal_fit_policy = "fit",
                                vertical_fit_policy = "fit",
                                id = "thumbnail",
                                widget = wibox.widget.imagebox
                            },
                            margins = thumbnail_margins,
                            widget = wibox.container.margin
                        },
                        {
                            icon_widget(),
                            {
                                {
                                    forced_width = name_forced_width,
                                    valign  = name_valign,
                                    id = "text_role",
                                    widget = wibox.widget.textbox
                                },
                                speed = name_scroll_speed,
                                step_function = name_scroll_step_function,
                                widget = wibox.container.scroll.horizontal
                            },
                            spacing = client_icon_horizontal_spacing,
                            layout = wibox.layout.fixed.horizontal
                        },
                        layout = wibox.layout.flex.vertical
                    }
                }
            }
        end

        return awful.widget.tasklist {
            screen = s,
            filter = awful.widget.tasklist.filter.currenttags,
            buttons = mouse_keys,
            style =  { font = name_font },
            layout = { layout  = wibox.layout.fixed.vertical, spacing = clients_spacing },
            widget_template =
            {
                widget = wibox.container.background,
                id = "bg_role",
                forced_width = client_width,
                forced_height = client_height,
                create_callback = function(self, c, _, __)
                    if (font_icons) ~= nil then
                        set_font_icon(self, c)
                        c:connect_signal("property::class", function() set_font_icon(self, c) end)
                    elseif (custom_icons) ~= nil then
                        set_custom_icon(self, c)
                        c:connect_signal("property::class", function() set_custom_icon(self, c) end)
                    end
                end,
                {
                    icon_widget(),
                    {
                        {
                            forced_width = name_forced_width,
                            valign  = name_valign,
                            id = "text_role",
                            widget = wibox.widget.textbox
                        },
                        speed = name_scroll_speed,
                        step_function = name_scroll_step_function,
                        widget = wibox.container.scroll.horizontal
                    },
                    spacing = client_icon_horizontal_spacing,
                    layout = wibox.layout.fixed.horizontal
                },
            },
        }
    end

    s.window_switcher_box = awful.popup
    ({
        bg = "#00000000",
        visible = false,
        ontop = true,
        placement = awful.placement.centered,
        screen = s,
        widget =
        {
            {
                tasklist_widget(),
                margins = client_margins,
                widget = wibox.container.margin
            },
            border_width = border_width,
            border_color = border_color,
            bg = background,
            shape = helpers.shape.rrect(border_radius),
            widget = wibox.container.background
        }
    })

    s.window_switcher_box:connect_signal("property::width", function()
        if s.window_switcher_box.visible and get_num_clients(s) == 0 then
            window_switcher_hide()
        end
    end)

    s.window_switcher_box:connect_signal("property::height", function()
        if s.window_switcher_box.visible and get_num_clients(s) == 0 then
            window_switcher_hide()
        end
    end)
end

local enable = function(opts)
    local opts = opts or {}

    local type = opts.type or "thumbnail"
    local background = beautiful.window_switcher_widget_bg or "#000000"
    local border_width = beautiful.window_switcher_widget_border_width or dpi(3)
    local border_radius = beautiful.window_switcher_widget_border_radius or dpi(0)
    local border_color = beautiful.window_switcher_widget_border_color or "#ffffff"
    local clients_spacing = beautiful.window_switcher_clients_spacing or dpi(20)
    local client_icon_horizontal_spacing = beautiful.window_switcher_client_icon_horizontal_spacing or dpi(5)
    local client_width = beautiful.window_switcher_client_width or dpi(type == "thumbnail" and 150 or 500)
    local client_height = beautiful.window_switcher_client_height or dpi(type == "thumbnail" and 250 or 50)
    local client_margins = beautiful.window_switcher_client_margins or dpi(10)
    local thumbnail_margins = beautiful.window_switcher_thumbnail_margins or dpi(5)
    local name_scroll_step_function = beautiful.name_scroll_step_function or wibox.container.scroll.step_functions.waiting_nonlinear_back_and_forth
    local name_scroll_speed = beautiful.name_scroll_speed or 20
    local name_valign = beautiful.window_switcher_name_valign or "center"
    local name_forced_width = beautiful.window_switcher_name_forced_width or dpi(type == "thumbnail" and 200 or 550)
    local name_font = beautiful.window_switcher_name_font or beautiful.font
    local icon_valign = beautiful.window_switcher_icon_valign  or "center"
    local icon_width = beautiful.window_switcher_icon_width or dpi(40)
    local custom_icons = beautiful.window_switcher_custom_icons or nil
    local font_icons = beautiful.window_switcher_font_icons or nil
    local font_icons_font = beautiful.window_switcher_font_icons_font or beautiful.font

    local hide_window_switcher_key = opts.hide_window_switcher_key or "Escape"

    local select_client_key = opts.select_client_key or 1
    local minimize_key = opts.minimize_key or "n"
    local unminimize_key = opts.unminimize_key or "N"
    local kill_client_key = opts.kill_client_key or "q"

    local cycle_key = opts.cycle_key or "Tab"

    local previous_key = opts.previous_key or "Left"
    local next_key = opts.next_key or "Right"

    local vim_previous_key = opts.vim_previous_key or "h"
    local vim_next_key = opts.vim_next_key or "l"

    local scroll_previous_key = opts.scroll_previous_key or 4
    local scroll_next_key = opts.scroll_next_key or 5

    local mouse_keys = gears.table.join
    (
        awful.button
        {
            modifiers = { "Any" },
            button = select_client_key,
            on_press = function(c)
                client.focus = c
            end,
        },

        awful.button
        {
            modifiers = { "Any" },
            button = scroll_previous_key,
            on_press = function()
                awful.client.focus.byidx(-1)
            end,
        },

        awful.button
        {
            modifiers = { "Any" },
            button = scroll_next_key,
            on_press = function()
                awful.client.focus.byidx(1)
            end,
        }
    )

    local keyboard_keys =
    {
        [hide_window_switcher_key] = window_switcher_hide,

        [minimize_key] = function() if client.focus then client.focus.minimized = true end end,
        [unminimize_key] = function() if awful.client.restore() then client.focus = awful.client.restore() end end,
        [kill_client_key] = function() if client.focus then client.focus:kill() end end,

        [cycle_key] = function() awful.client.focus.byidx(1) end,

        [previous_key] = function() awful.client.focus.byidx(1) end,
        [next_key] = function() awful.client.focus.byidx(-1) end,

        [vim_previous_key] = function() awful.client.focus.byidx(1) end,
        [vim_next_key] = function() awful.client.focus.byidx(-1) end,
    }

    awesome.connect_signal("bling::window_switcher::visibility", function(s)
        local number_of_clients = get_num_clients(s)
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
        local clients = s.selected_tag:clients()
        for _, c in pairs(clients) do
            if c.minimized then
                table.insert(window_switcher_minimized_clients, c)
                c.minimized = false
                c:lower()
            end
        end

        -- Start the keygrabber
        window_switcher_grabber = awful.keygrabber.run(function(_, key, event)
            if event == "release" then
                -- Hide if the modifier was released
                -- We try to match Super or Alt or Control since we do not know which keybind is
                -- used to activate the window switcher (the keybind is set by the user in keys.lua)
                if key:match("Super") or key:match("Alt") or key:match("Control") then
                    window_switcher_hide()
                end
                -- Do nothing
                return
            end

            -- Run function attached to key, if it exists
            if keyboard_keys[key] then
                keyboard_keys[key]()
            end
        end)

        gears.timer.delayed_call(function()
            -- Finally make the window switcher wibox visible after
            -- a small delay, to allow the popup size to update
            draw_widget(s, type, background, border_width, border_radius, border_color, clients_spacing, client_icon_horizontal_spacing, client_width, client_height, client_margins, thumbnail_margins, name_scroll_step_function, name_scroll_speed, name_valign, name_forced_width, name_font, icon_valign, icon_width, custom_icons, font_icons, font_icons_font, mouse_keys)
            s.window_switcher_box.visible = true
        end)
    end)
end

return {enable = enable}
