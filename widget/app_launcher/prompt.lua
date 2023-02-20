-------------------------------------------
-- @author https://github.com/Kasper24
-- @copyright 2021-2022 Kasper24
-------------------------------------------
local awful = require("awful")
local gtable = require("gears.table")
local gstring = require("gears.string")
local wibox = require("wibox")
local beautiful = require("beautiful")
local dpi = beautiful.xresources.apply_dpi
local tostring = tostring
local tonumber = tonumber
local ceil = math.ceil
local ipairs = ipairs
local string = string
local type = type
local capi = {
    awesome = awesome,
    root = root,
    mouse = mouse,
    tag = tag,
    client = client
}

local prompt = {
    mt = {}
}

local properties = {
    "only_numbers", "round", "obscure",
    "always_on", "reset_on_stop",
    "stop_on_lost_focus", "stop_on_tag_changed", "stop_on_clicked_outside",
    "icon_font", "icon_size", "icon_color", "icon",
    "label_font", "label_size", "label_color", "label",
    "text_font", "text_size", "text_color", "text",
    "cursor_size", "cursor_color"
}

local function is_word_char(c)
    if string.find(c, "[{[(,.:;_-+=@/ ]") then
        return false
    else
        return true
    end
end

local function cword_start(s, pos)
    local i = pos
    if i > 1 then
        i = i - 1
    end
    while i >= 1 and not is_word_char(s:sub(i, i)) do
        i = i - 1
    end
    while i >= 1 and is_word_char(s:sub(i, i)) do
        i = i - 1
    end
    if i <= #s then
        i = i + 1
    end
    return i
end

local function cword_end(s, pos)
    local i = pos
    while i <= #s and not is_word_char(s:sub(i, i)) do
        i = i + 1
    end
    while i <= #s and is_word_char(s:sub(i, i)) do
        i = i + 1
    end
    return i
end

local function have_multibyte_char_at(text, position)
    return text:sub(position, position):wlen() == -1
end

local function generate_markup(self)
    local wp = self._private

    local label_size = dpi(ceil(wp.label_size * 1024))
    local text_size = dpi(ceil(wp.text_size * 1024))
    local cursor_size = dpi(ceil(wp.cursor_size * 1024))

    local text = tostring(wp.text) or ""
    if wp.obscure == true then
        text = text:gsub(".", "*")
    end

    local markup = ""
    if wp.icon ~= nil then
        if type(wp.icon) == "table" then
            local icon_size = dpi(ceil(wp.icon.size * 1024))
            markup = string.format(
                '<span font_family="%s" font_size="%s" foreground="%s">%s  </span>',
                wp.icon.font, icon_size, wp.icon.color, wp.icon.icon)
        else
            local icon_size = dpi(ceil(wp.icon_size * 1024))
            markup = string.format(
                '<span font_family="%s" font_size="%s" foreground="%s">%s  </span>',
                wp.icon_font, icon_size, wp.icon_color, wp.icon)
        end
    end

    if self._private.state == true then
        local char, spacer, text_start, text_end

        if #text < wp.cur_pos then
            char = " "
            spacer = ""
            text_start = gstring.xml_escape(text)
            text_end = ""
        else
            local offset = 0
            if have_multibyte_char_at(text, wp.cur_pos) then
                offset = 1
            end
            char = gstring.xml_escape(text:sub(wp.cur_pos, wp.cur_pos + offset))
            spacer = " "
            text_start = gstring.xml_escape(text:sub(1, wp.cur_pos - 1))
            text_end = gstring.xml_escape(text:sub(wp.cur_pos + offset))
        end

        markup = markup .. (string.format(
            '<span font_family="%s" font_size="%s" foreground="%s">%s</span>' ..
            '<span font_family="%s" font_size="%s" foreground="%s">%s</span>' ..
            '<span font_size="%s" background="%s">%s</span>' ..
            '<span font_family="%s" font_size="%s" foreground="%s">%s%s</span>',
            wp.label_font, label_size, wp.label_color, wp.label,
            wp.text_font, text_size, wp.text_color, text_start,
            cursor_size, wp.cursor_color, char,
            wp.text_font, text_size, wp.text_color, text_end,
            spacer))
    else
        markup = markup .. string.format(
                '<span font_family="%s" font_size="%s" foreground="%s">%s</span>' ..
                '<span font_family="%s" font_size="%s" foreground="%s">%s</span>',
                wp.label_font, label_size, wp.label_color, wp.label,
                wp.text_font, text_size, wp.text_color, gstring.xml_escape(text))
    end

    self:set_markup(markup)
end

local function paste(self)
    local wp = self._private

    awful.spawn.easy_async_with_shell("xclip -selection clipboard -o", function(stdout)
        if stdout ~= nil then
            local n = stdout:find("\n")
            if n then
                stdout = stdout:sub(1, n - 1)
            end

            wp.text = wp.text:sub(1, wp.cur_pos - 1) .. stdout .. self.text:sub(wp.cur_pos)
            wp.cur_pos = wp.cur_pos + #stdout
            generate_markup(self)
        end
    end)
end

local function build_properties(prototype, prop_names)
    for _, prop in ipairs(prop_names) do
        if not prototype["set_" .. prop] then
            prototype["set_" .. prop] = function(self, value)
                if self._private[prop] ~= value then
                    self._private[prop] = value
                    self:emit_signal("widget::redraw_needed")
                    self:emit_signal("property::" .. prop, value)
                    generate_markup(self)
                end
                return self
            end
        end
        if not prototype["get_" .. prop] then
            prototype["get_" .. prop] = function(self)
                return self._private[prop]
            end
        end
    end
end

function prompt:toggle_obscure()
    self:set_obscure(not self._private.obscure)
end

function prompt:set_text(text)
    self._private.text = text
    self._private.cur_pos = #text + 1
    generate_markup(self)
end

function prompt:get_text()
    return self._private.text
end

function prompt:start()
    local wp = self._private
    wp.state = true

    capi.awesome.emit_signal("prompt::toggled_on", self)
    generate_markup(self)

    wp.grabber = awful.keygrabber.run(function(modifiers, key, event)
        -- Convert index array to hash table
        local mod = {}
        for _, v in ipairs(modifiers) do
            mod[v] = true
        end

        if event ~= "press" then
            self:emit_signal("key::release", mod, key, wp.text)
            return
        end

        self:emit_signal("key::press", mod, key, wp.text)

        -- Control cases
        if mod.Control then
            if key == "v" then
                paste(self)
            elseif key == "a" then
                wp.cur_pos = 1
            elseif key == "b" then
                if wp.cur_pos > 1 then
                    wp.cur_pos = wp.cur_pos - 1
                    if have_multibyte_char_at(wp.text, wp.cur_pos) then
                        wp.cur_pos = wp.cur_pos - 1
                    end
                end
            elseif key == "d" then
                if wp.cur_pos <= #wp.text then
                    wp.text = wp.text:sub(1, wp.cur_pos - 1) .. wp.text:sub(wp.cur_pos + 1)
                end
            elseif key == "e" then
                wp.cur_pos = #wp.text + 1
            elseif key == "f" then
                if wp.cur_pos <= #wp.text then
                    if have_multibyte_char_at(wp.text, wp.cur_pos) then
                        wp.cur_pos = wp.cur_pos + 2
                    else
                        wp.cur_pos = wp.cur_pos + 1
                    end
                end
            elseif key == "h" then
                if wp.cur_pos > 1 then
                    local offset = 0
                    if have_multibyte_char_at(wp.text, wp.cur_pos - 1) then
                        offset = 1
                    end
                    wp.text = wp.text:sub(1, wp.cur_pos - 2 - offset) .. wp.text:sub(wp.cur_pos)
                    wp.cur_pos = wp.cur_pos - 1 - offset
                end
            elseif key == "k" then
                wp.text = wp.text:sub(1, wp.cur_pos - 1)
            elseif key == "u" then
                wp.text = wp.text:sub(wp.cur_pos, #wp.text)
                wp.cur_pos = 1
            elseif key == "w" or key == "BackSpace" then
                local wstart = 1
                local wend = 1
                local cword_start_pos = 1
                local cword_end_pos = 1
                while wend < wp.cur_pos do
                    wend = wp.text:find("[{[(,.:;_-+=@/ ]", wstart)
                    if not wend then
                        wend = #wp.text + 1
                    end
                    if wp.cur_pos >= wstart and wp.cur_pos <= wend + 1 then
                        cword_start_pos = wstart
                        cword_end_pos = wp.cur_pos - 1
                        break
                    end
                    wstart = wend + 1
                end
                wp.text = wp.text:sub(1, cword_start_pos - 1) .. wp.text:sub(cword_end_pos + 1)
                wp.cur_pos = cword_start_pos
            end
        elseif mod.Mod1 or mod.Mod3 then
            if key == "b" then
                wp.cur_pos = cword_start(wp.text, wp.cur_pos)
            elseif key == "f" then
                wp.cur_pos = cword_end(wp.text, wp.cur_pos)
            elseif key == "d" then
                wp.text = wp.text:sub(1, wp.cur_pos - 1) .. wp.text:sub(cword_end(wp.text, wp.cur_pos))
            elseif key == "BackSpace" then
                local wstart = cword_start(wp.text, wp.cur_pos)
                wp.text = wp.text:sub(1, wstart - 1) .. wp.text:sub(wp.cur_pos)
                wp.cur_pos = wstart
            end
        else
            if key == "Escape" or key == "Return" then
                if self.always_on == false then
                    self:stop()
                    return
                end
            elseif mod.Shift and key == "Insert" then
                paste(self)
            elseif key == "Home" then
                wp.cur_pos = 1
            elseif key == "End" then
                wp.cur_pos = #wp.text + 1
            elseif key == "BackSpace" then
                if wp.cur_pos > 1 then
                    local offset = 0
                    if have_multibyte_char_at(wp.text, wp.cur_pos - 1) then
                        offset = 1
                    end
                    wp.text = wp.text:sub(1, wp.cur_pos - 2 - offset) .. wp.text:sub(wp.cur_pos)
                    wp.cur_pos = wp.cur_pos - 1 - offset
                end
            elseif key == "Delete" then
                wp.text = wp.text:sub(1, wp.cur_pos - 1) .. wp.text:sub(wp.cur_pos + 1)
            elseif key == "Left" then
                wp.cur_pos = wp.cur_pos - 1
            elseif key == "Right" then
                wp.cur_pos = wp.cur_pos + 1
            else
                if wp.round and key == "." then
                    return
                end
                if wp.only_numbers and tonumber(wp.text .. key) == nil then
                    return
                end

                -- wlen() is UTF-8 aware but #key is not,
                -- so check that we have one UTF-8 char but advance the cursor of # position
                if key:wlen() == 1 then
                    wp.text = wp.text:sub(1, wp.cur_pos - 1) .. key .. wp.text:sub(wp.cur_pos)
                    wp.cur_pos = wp.cur_pos + #key
                end
            end
            if wp.cur_pos < 1 then
                wp.cur_pos = 1
            elseif wp.cur_pos > #wp.text + 1 then
                wp.cur_pos = #wp.text + 1
            end
        end

        if wp.only_numbers and wp.text == "" then
            wp.text = "0"
            wp.cur_pos = #wp.text + 1
        end

        generate_markup(self)
        self:emit_signal("text::changed", wp.text)
    end)
end

function prompt:stop()
    local wp = self._private
    wp.state = false

    if self.reset_on_stop == true or wp.cur_pos == nil then
        wp.cur_pos = wp.text:wlen() + 1
    end
    if self.reset_on_stop == true then
        wp.text = ""
    end

    awful.keygrabber.stop(wp.grabber)
    generate_markup(self)

    self:emit_signal("stopped", wp.text)
end

function prompt:toggle()
    local wp = self._private

    if wp.state == true then
        self:stop()
    else
        self:start()
    end
end

local function new()
    local widget = wibox.widget.textbox()
    gtable.crush(widget, prompt, true)

    local wp = widget._private

    wp.only_numbers = false
    wp.round = false
    wp.always_on = false
    wp.reset_on_stop = false
    wp.obscure = false
    wp.stop_on_focus_lost = false
    wp.stop_on_tag_changed = false
    wp.stop_on_clicked_outside = true

    wp.icon_font = beautiful.font
    wp.icon_size = 12
    wp.icon_color = beautiful.colors.on_background
    wp.icon = nil

    wp.label_font = beautiful.font
    wp.label_size = 12
    wp.label_color = beautiful.colors.on_background
    wp.label = ""

    wp.text_font = beautiful.font
    wp.text_size = 12
    wp.text_color = beautiful.colors.on_background
    wp.text = ""

    wp.cursor_size = 4
    wp.cursor_color = beautiful.colors.on_background

    wp.cur_pos = #wp.text + 1 or 1
    wp.state = false

    widget:connect_signal("mouse::enter", function(self, find_widgets_result)
        capi.root.cursor("xterm")
        local wibox = capi.mouse.current_wibox
        if wibox then
            wibox.cursor = "xterm"
        end
    end)

    widget:connect_signal("mouse::leave", function()
        capi.root.cursor("left_ptr")
        local wibox = capi.mouse.current_wibox
        if wibox then
            wibox.cursor = "left_ptr"
        end

        if wp.stop_on_focus_lost ~= false and wp.always_on == false and wp.state == true then
            widget:stop()
        end
    end)

    widget:connect_signal("button::press", function(self, lx, ly, button, mods, find_widgets_result)
        if wp.always_on then
            return
        end

        if button == 1 then
            widget:toggle()
        end
    end)

    -- TODO make it work outside my config
    capi.awesome.connect_signal("root::pressed", function()
        if wp.stop_on_clicked_outside ~= false and wp.always_on == false and wp.state == true then
            widget:stop()
        end
    end)

    capi.client.connect_signal("button::press", function()
        if wp.stop_on_clicked_outside ~= false and wp.always_on == false and wp.state == true then
            widget:stop()
        end
    end)

    capi.tag.connect_signal("property::selected", function()
        if wp.stop_on_tag_changed ~= false and wp.always_on == false and wp.state == true then
            widget:stop()
        end
    end)

    capi.awesome.connect_signal("prompt::toggled_on", function(prompt)
        if wp.always_on == false and prompt ~= widget and wp.state == true then
            widget:stop()
        end
    end)

    return widget
end

function prompt.mt:__call(...)
    return new(...)
end

build_properties(prompt, properties)

return setmetatable(prompt, prompt.mt)
