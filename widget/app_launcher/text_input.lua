-------------------------------------------
-- @author https://github.com/Kasper24
-- @copyright 2021-2022 Kasper24
-------------------------------------------
local lgi = require('lgi')
local Gtk = lgi.require('Gtk', '3.0')
local Gdk = lgi.require('Gdk', '3.0')
local Pango = lgi.Pango
local awful = require("awful")
local gtable = require("gears.table")
local gtimer = require("gears.timer")
local gcolor = require("gears.color")
local wibox = require("wibox")
local beautiful = require("beautiful")
local ipairs = ipairs
local string = string
local capi = {
    awesome = awesome,
    root = root,
    tag = tag,
    client = client,
    mouse = mouse,
    mousegrabber = mousegrabber
}

local text_input = {
    mt = {}
}

local properties = {
    "unfocus_keys",
    "unfocus_on_root_clicked", "unfocus_on_client_clicked", "unfocus_on_client_focus",
    "unfocus_on_mouse_leave", "unfocus_on_tag_change",
    "focus_on_subject_mouse_enter", "unfocus_on_subject_mouse_leave",
    "click_timeout",
    "reset_on_unfocus",
    "text_color",
    "placeholder", "initial",
    "pattern", "obscure",
    "cursor_blink", "cursor_blink_rate","cursor_size", "cursor_bg",
    "selection_bg"
}

text_input.patterns = {
    numbers = "[%d.]*",
    numbers_one_decimal = "%d*%.?%d*",
    round_numbers = "[0-9]*",
    email = "%S+@%S+%.%S+",
    time = "%d%d?:%d%d:%d%d?|%d%d?:%d%d",
    date = "%d%d%d%d%-%d%d%-%d%d|%d%d?/%d%d?/%d%d%d%d|%d%d?%.%d%d?%.%d%d%d%d",
    phone = "%+?%d[%d%-%s]+%d",
    url = "https?://[%w-_%.]+%.[%w]+/?[%w-_%.?=%+]*",
    email = "[%w._%-%+]+@[%w._%-]+%.%w+",
    alphanumeric = "%w+",
    letters = "[a-zA-Z]+"
}

local function build_properties(prototype, prop_names)
    for _, prop in ipairs(prop_names) do
        if not prototype["set_" .. prop] then
            prototype["set_" .. prop] = function(self, value)
                if self._private[prop] ~= value then
                    self._private[prop] = value
                    self:emit_signal("widget::redraw_needed")
                    self:emit_signal("property::" .. prop, value)
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

local function has_value(tab, val)
    for _, value in ipairs(tab) do
        if val:lower():find(value:lower(), 1, true) then
            return true
        end
    end
    return false
end

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

local function set_mouse_cursor(cursor)
    capi.root.cursor(cursor)
    local wibox = capi.mouse.current_wibox
    if wibox then
        wibox.cursor = cursor
    end
end

local function single_double_triple_tap(self, args)
    local wp = self._private

    if wp.click_timer == nil then
        wp.click_timer = gtimer {
            timeout = wp.click_timeout,
            autostart = false,
            call_now = false,
            single_shot = true,
            callback = function()
                wp.click_count = 0
            end
        }
    end

    wp.click_timer:again()
    wp.click_count = wp.click_count + 1
    if wp.click_count == 1 then
        args.on_single_click()
    elseif wp.click_count == 2 then
        args.on_double_click()
    elseif wp.click_count == 3 then
        args.on_triple_click()
        wp.click_count = 0
    end
end

local function run_keygrabber(self)
    local wp = self._private
    wp.keygrabber = awful.keygrabber.run(function(modifiers, key, event)
        if event ~= "press" then
            self:emit_signal("key::release", modifiers, key, event)
            return
        end
        self:emit_signal("key::press", modifiers, key, event)

        -- Convert index array to hash table
        local mod = {}
        for _, v in ipairs(modifiers) do
            mod[v] = true
        end

        if mod.Control then
            if key == "a" then
                self:select_all()
            elseif key == "c" then
                self:copy()
            elseif key == "v" then
                self:paste()
            elseif key == "b" or key == "Left" then
                self:set_cursor_index_to_word_start()
            elseif key == "f" or key == "Right" then
                self:set_cursor_index_to_word_end()
            elseif key == "d" then
                self:delete_next_word()
            elseif key == "BackSpace" then
                self:delete_previous_word()
            end
        elseif mod.Shift and key:wlen() ~= 1 then
            if key =="Left" then
                self:decremeant_selection_end_index()
            elseif key == "Right" then
                self:increamant_selection_end_index()
            end
        else
            if has_value(wp.unfocus_keys, key) then
                self:unfocus()
            end

            if mod.Shift and key == "Insert" then
                self:paste()
            elseif key == "Home" then
                self:set_cursor_index(0)
            elseif key == "End" then
                self:set_cursor_index_to_end()
            elseif key == "BackSpace" then
                self:delete_text()
            elseif key == "Delete" then
                self:delete_text_after_cursor()
            elseif key == "Left" then
                self:decremeant_cursor_index()
            elseif key == "Right" then
                self:increamant_cursor_index()
            elseif key:wlen() == 1 then
                self:update_text(key)
            end
        end
    end)
end

function text_input:set_widget_template(widget_template)
    local wp = self._private

    wp.text_widget = widget_template:get_children_by_id("text_role")[1]
    wp.text_widget.forced_width = math.huge
    local text_draw = wp.text_widget.draw
    if self:get_initial() then
        self:set_text(self:get_initial())
    end

    local placeholder_widget = widget_template:get_children_by_id("placeholder_role")
    if placeholder_widget then
        placeholder_widget = placeholder_widget[1]
    end

    function wp.text_widget:draw(context, cr, width, height)
        local _, logical_rect = self._private.layout:get_pixel_extents()

        -- Selection bg
        cr:set_source(gcolor.change_opacity(wp.selection_bg, wp.selection_opacity))
        cr:rectangle(
            wp.selection_start_x,
            logical_rect.y - 3,
            wp.selection_end_x - wp.selection_start_x,
            logical_rect.y + logical_rect.height + 6
        )
        cr:fill()

        -- Cursor
        cr:set_source(gcolor.change_opacity(wp.cursor_bg, wp.cursor_opacity))
        cr:set_line_width(wp.cursor_width)
        cr:move_to(wp.cursor_x, logical_rect.y - 3)
        cr:line_to(wp.cursor_x, logical_rect.y + logical_rect.height + 6)
        cr:stroke()

        cr:set_source(gcolor(wp.text_color))
        text_draw(self, context, cr, width, height)

        if self:get_text() == "" and placeholder_widget then
            placeholder_widget.visible = true
        elseif placeholder_widget then
            placeholder_widget.visible = false
        end
    end

    local function on_drag(_, lx, ly)
        if not wp.selecting_text and (lx ~= wp.press_pos.lx or ly ~= wp.press_pos.ly) then
            self:set_selection_start_index_from_x_y(wp.press_pos.lx, wp.press_pos.ly)
            self:set_selection_end_index(wp.selection_start)
            wp.selecting_text = true
        elseif wp.selecting_text then
            self:set_selection_end_index_from_x_y(lx - wp.offset.x, ly - wp.offset.y)
        end
    end

    wp.text_widget:connect_signal("button::press", function(_, lx, ly, button, mods, find_widgets_result)
        if button == 1 then
            single_double_triple_tap(self, {
                on_single_click = function()
                    self:focus()
                    self:set_cursor_index_from_x_y(lx, ly)
                end,
                on_double_click = function()
                    self:set_selection_to_word()
                end,
                on_triple_click = function()
                    self:select_all()
                end
            })

            wp.press_pos = { lx = lx, ly = ly }
            wp.offset = { x = find_widgets_result.x, y = find_widgets_result.y }
            find_widgets_result.drawable:connect_signal("mouse::move", on_drag)
        end
    end)

    wp.text_widget:connect_signal("button::release", function(_, lx, ly, button, mods, find_widgets_result)
        if button == 1 then
            find_widgets_result.drawable:disconnect_signal("mouse::move", on_drag)
            wp.selecting_text = false
        end
    end)

    wp.text_widget:connect_signal("mouse::enter", function()
        set_mouse_cursor("xterm")
    end)

    wp.text_widget:connect_signal("mouse::leave", function(_, find_widgets_result)
        if self:get_focused() == false then
            set_mouse_cursor("left_ptr")
        end

        find_widgets_result.drawable:disconnect_signal("mouse::move", on_drag)
        if wp.unfocus_on_mouse_leave then
            self:unfocus()
        end
    end)

    self:set_widget(widget_template)
end

function text_input:get_mode()
    return self._private.mode
end

function text_input:set_focused(focused)
    if focused == true then
       self:focus()
    else
        self:unfocus()
    end
end

function text_input:set_pattern(pattern)
    self._private.pattern = text_input.patterns[pattern]
end

function text_input:toggle_obscure()
    self:set_obscure(not self._private.obscure)
end

function text_input:set_initial(initial)
    self._private.initial = initial
    self:set_text(initial)
end

function text_input:update_text(text)
    if self:get_mode() == "insert" then
        self:insert_text(text)
    else
        self:overwrite_text(text)
    end
end

function text_input:set_text(text)
    local text_widget = self:get_text_widget()

    text_widget:set_text(text)
    if text_widget:get_text() == "" then
        self:set_cursor_index(0)
    else
        self:set_cursor_index(#text)
    end
end

function text_input:insert_text(text)
    local wp = self._private

    local old_text = self:get_text()
    local cursor_index = self:get_cursor_index()
    local left_text = old_text:sub(1, cursor_index) .. text
    local right_text = old_text:sub(cursor_index + 1)
    local new_text = left_text .. right_text
    if wp.pattern then
        new_text = new_text:match(wp.pattern)
        if new_text then
            self:get_text_widget():set_text(new_text)
            self:set_cursor_index(self:get_cursor_index() + #text)
            self:emit_signal("property::text", self:get_text())
        end
    else
        self:get_text_widget():set_text(new_text)
        self:set_cursor_index(self:get_cursor_index() + #text)
        self:emit_signal("property::text", self:get_text())
    end
end

function text_input:overwrite_text(text)
    local wp = self._private

    local start_pos = wp.selection_start
    local end_pos = wp.selection_end
    if start_pos > end_pos then
        start_pos, end_pos = end_pos, start_pos
    end

    local old_text = self:get_text()
    local left_text = old_text:sub(1, start_pos)
    local right_text = old_text:sub(end_pos + 1)
    local new_text = left_text .. text .. right_text

    if wp.pattern then
        new_text = new_text:match(wp.pattern)
        if new_text then
            self:get_text_widget():set_text(new_text)
            self:set_cursor_index(#left_text)
            self:emit_signal("property::text", self:get_text())
        end
    else
        self:get_text_widget():set_text(new_text)
        self:set_cursor_index(#left_text)
        self:emit_signal("property::text", self:get_text())
    end
end

function text_input:copy()
    local wp = self._private
    if self:get_mode() == "overwrite" then
        local text = self:get_text()
        local start_pos = self._private.selection_start
        local end_pos = self._private.selection_end
        if start_pos > end_pos then
            start_pos, end_pos = end_pos + 1, start_pos
        end
        text = text:sub(start_pos, end_pos)
        wp.clipboard:set_text(text, -1)
    end
end

function text_input:paste()
    local wp = self._private

    wp.clipboard:request_text(function(clipboard, text)
        if text then
            self:update_text(text)
        end
    end)
end

function text_input:delete_next_word()
    local old_text = self:get_text()
    local cursor_index = self:get_cursor_index()

    local left_text = old_text:sub(1, cursor_index)
    local right_text = old_text:sub(cword_end(old_text, cursor_index + 1))
    self:get_text_widget():set_text(left_text .. right_text)
    self:emit_signal("property::text", self:get_text())
end

function text_input:delete_previous_word()
    local old_text = self:get_text()
    local cursor_index = self:get_cursor_index()
    local wstart = cword_start(old_text, cursor_index + 1) - 1
    local left_text = old_text:sub(1, wstart)
    local right_text = old_text:sub(cursor_index + 1)
    self:get_text_widget():set_text(left_text .. right_text)
    self:set_cursor_index(wstart)
    self:emit_signal("property::text", self:get_text())
end

function text_input:delete_text()
    if self:get_mode() == "insert" then
        self:delete_text_before_cursor()
    else
        self:overwrite_text("")
    end
end

function text_input:delete_text_before_cursor()
    local cursor_index = self:get_cursor_index()
    if cursor_index > 0 then
        local old_text = self:get_text()
        local left_text = old_text:sub(1, cursor_index - 1)
        local right_text = old_text:sub(cursor_index + 1)
        self:get_text_widget():set_text(left_text .. right_text)
        self:set_cursor_index(cursor_index - 1)
        self:emit_signal("property::text", self:get_text())
    end
end

function text_input:delete_text_after_cursor()
    local cursor_index = self:get_cursor_index()
    if cursor_index < #self:get_text() then
        local old_text = self:get_text()
        local left_text = old_text:sub(1, cursor_index)
        local right_text = old_text:sub(cursor_index + 2)
        self:get_text_widget():set_text(left_text .. right_text)
        self:emit_signal("property::text", self:get_text())
    end
end

function text_input:get_text()
    return self:get_text_widget():get_text()
end

function text_input:get_text_widget()
    return self._private.text_widget
end

function text_input:show_selection()
    self._private.selection_opacity = 1
    self:get_text_widget():emit_signal("widget::redraw_needed")
end

function text_input:hide_selection()
    self._private.selection_opacity = 0
    self:get_text_widget():emit_signal("widget::redraw_needed")
end

function text_input:select_all()
    if self:get_text() == "" then
        return
    end

    self:set_selection_start_index(0)
    self:set_selection_end_index(#self:get_text())
end

function text_input:set_selection_to_word()
    if self:get_text() == "" then
        return
    end

    local word_start_index = cword_start(self:get_text(), self:get_cursor_index() + 1) - 1
    local word_end_index = cword_end(self:get_text(), self:get_cursor_index() + 1) - 1

    self:set_selection_start_index(word_start_index)
    self:set_selection_end_index(word_end_index)
end

function text_input:set_selection_start_index(index)
    index = math.max(math.min(index, #self:get_text()), 0)

    local layout = self:get_text_widget()._private.layout
    local strong_pos, weak_pos = layout:get_caret_pos(index)
    if strong_pos then
        self._private.selection_start = index
        self._private.mode = "overwrite"

        self._private.selection_start_x = strong_pos.x / Pango.SCALE
        self._private.selection_start_y = strong_pos.y / Pango.SCALE

        self:show_selection()
        self:hide_cursor()

        self:get_text_widget():emit_signal("widget::redraw_needed")
    end
end

function text_input:set_selection_end_index(index)
    index = math.max(math.min(index, #self:get_text()), 0)

    local layout = self:get_text_widget()._private.layout
    local strong_pos, weak_pos = layout:get_caret_pos(index)
    if strong_pos then
        self._private.selection_end_x = strong_pos.x / Pango.SCALE
        self._private.selection_end_y = strong_pos.y / Pango.SCALE
        self._private.selection_end = index
        self:get_text_widget():emit_signal("widget::redraw_needed")
    end
end

function text_input:increamant_selection_end_index()
    if self:get_mode() == "insert" then
        self:set_selection_start_index(self:get_cursor_index())
        self:set_selection_end_index(self:get_cursor_index() + 1)
    else
        self:set_selection_end_index(self._private.selection_end + 1)
    end
end

function text_input:decremeant_selection_end_index()
    if self:get_mode() == "insert" then
        self:set_selection_start_index(self:get_cursor_index())
        self:set_selection_end_index(self:get_cursor_index() - 1)
    else
        self:set_selection_end_index(self._private.selection_end - 1)
    end
end

function text_input:set_selection_start_index_from_x_y(x, y)
    local layout = self:get_text_widget()._private.layout
    local index, trailing = layout:xy_to_index(x * Pango.SCALE, y * Pango.SCALE)
    if index then
        self:set_selection_start_index(index)
    else
        self:set_selection_start_index(#self:get_text())
    end
end

function text_input:set_selection_end_index_from_x_y(x, y)
    local layout = self:get_text_widget()._private.layout
    local index, trailing = layout:xy_to_index(x * Pango.SCALE, y * Pango.SCALE)
    if index then
        self:set_selection_end_index(index + trailing)
    end
end

function text_input:show_cursor()
    self._private.cursor_opacity = 1
    self:get_text_widget():emit_signal("widget::redraw_needed")
end

function text_input:hide_cursor()
    self._private.cursor_opacity = 0
    self:get_text_widget():emit_signal("widget::redraw_needed")
end

function text_input:set_cursor_index(index)
    index = math.max(math.min(index, #self:get_text()), 0)

    local layout = self:get_text_widget()._private.layout
    local strong_pos, weak_pos = layout:get_cursor_pos(index)
    if strong_pos then
        if strong_pos == self._private.cursor_index and self._private.mode == "insert" then
            return
        end

        self._private.cursor_index = index
        self._private.mode = "insert"

        self._private.cursor_x = strong_pos.x / Pango.SCALE
        self._private.cursor_y = strong_pos.y / Pango.SCALE

        if self:get_focused() then
            self:show_cursor()
        end
        self:hide_selection()

        self:get_text_widget():emit_signal("widget::redraw_needed")
    end
end

function text_input:set_cursor_index_from_x_y(x, y)
    local layout = self:get_text_widget()._private.layout
    local index, trailing = layout:xy_to_index(x * Pango.SCALE, y * Pango.SCALE)

    if index then
        self:set_cursor_index(index)
    else
        local _, logical_rect = self:get_text_widget()._private.layout:get_pixel_extents()
        if x < logical_rect.width then
            self:set_cursor_index(0)
        else
            self:set_cursor_index(#self:get_text())
        end
    end
end

function text_input:set_cursor_index_to_word_start()
    self:set_cursor_index(cword_start(self:get_text(), self:get_cursor_index() + 1) - 1)
end

function text_input:set_cursor_index_to_word_end()
    self:set_cursor_index(cword_end(self:get_text(), self:get_cursor_index() + 1) - 1)
end

function text_input:set_cursor_index_to_end()
    self:set_cursor_index(#self:get_text())
end

function text_input:increamant_cursor_index()
    if self:get_mode() == "insert" then
        self:set_cursor_index(self:get_cursor_index() + 1)
    else
        local start_pos = self._private.selection_start
        local end_pos = self._private.selection_end
        if start_pos > end_pos then
            start_pos, end_pos = end_pos, start_pos
        end
        self:set_cursor_index(end_pos)
    end
end

function text_input:decremeant_cursor_index()
    if self:get_mode() == "insert" then
        self:set_cursor_index(self:get_cursor_index() - 1)
    else
        local start_pos = self._private.selection_start
        local end_pos = self._private.selection_end
        if start_pos > end_pos then
            start_pos, end_pos = end_pos, start_pos
        end
        self:set_cursor_index(start_pos)
    end
end

function text_input:get_cursor_index()
    return self._private.cursor_index
end

function text_input:set_focus_on_subject_mouse_enter(subject)
    subject:connect_signal("mouse::enter", function()
        self:focus()
    end)
end

function text_input:set_unfocus_on_subject_mouse_leave(subject)
    subject:connect_signal("mouse::leave", function()
        self:unfocus()
    end)
end

function text_input:get_focused()
    return self._private.focused
end

function text_input:focus()
    local wp = self._private

    if self:get_focused() == true then
        return
    end

    -- Do it first, so the cursor won't change back when unfocus was called on the focused text input
    capi.awesome.emit_signal("text_input::focus", self)

    set_mouse_cursor("xterm")

    if self:get_mode() == "insert" then
        self:show_cursor()
    end

    run_keygrabber(self)

    if wp.cursor_blink then
        gtimer.start_new(wp.cursor_blink_rate, function()
            if self:get_focused() == true then
                if self._private.cursor_opacity == 1 then
                    self:hide_cursor()
                elseif self:get_mode() == "insert" then
                    self:show_cursor()
                end
                return true
            end
            return false
        end)
    end

    wp.focused = true
    self:emit_signal("focus")
end

function text_input:unfocus(context)
    local wp = self._private
    if self:get_focused() == false then
        return
    end

    set_mouse_cursor("left_ptr")
    self:hide_cursor()
    self:hide_selection()
    if self.reset_on_unfocus == true then
        self:set_text("")
    end

    awful.keygrabber.stop(wp.keygrabber)
    wp.focused = false
    self:emit_signal("unfocus", context or "normal", self:get_text())
end

function text_input:toggle()
    local wp = self._private

    if self:get_focused() == false then
        self:focus()
    else
        self:unfocus()
    end
end

local function new()
    local widget = wibox.container.background()
    gtable.crush(widget, text_input, true)

    local wp = widget._private

    wp.focused = false
    wp.clipboard = Gtk.Clipboard.get(Gdk.SELECTION_CLIPBOARD)
    wp.cursor_index = 0
    wp.mode = "insert"
    wp.click_count = 0

    wp.cursor_x = 0
    wp.cursor_y = 0
    wp.cursor_opacity = 0
    wp.selection_start_x = 0
    wp.selection_end_x = 0
    wp.selection_start_y = 0
    wp.selection_end_y = 0
    wp.selection_opacity = 0
    wp.selecting_text = false

    wp.click_timeout = 0.3

    wp.unfocus_keys = { }
    wp.unfocus_on_root_clicked = false
    wp.unfocus_on_client_clicked = false
    wp.unfocus_on_mouse_leave = false
    wp.unfocus_on_tag_change = false
    wp.unfocus_on_other_text_input_focus = false
    wp.unfocus_on_client_focus = false

    wp.focus_on_subject_mouse_enter = nil
    wp.unfocus_on_subject_mouse_leave = nil

    wp.reset_on_unfocus = true

    wp.pattern = nil
    wp.obscure = false

    wp.placeholder = ""
    wp.text_color = beautiful.fg_normal
    wp.text = ""

    wp.cursor_width = 2
    wp.cursor_bg = beautiful.fg_normal
    wp.cursor_blink = true
    wp.cursor_blink_rate = 0.6

    wp.selection_bg = beautiful.bg_normal

    widget:set_widget_template(wibox.widget {
        layout = wibox.layout.stack,
        {
            widget = wibox.widget.textbox,
            id = "placeholder_role",
            text = wp.placeholder
        },
        {
            widget = wibox.widget.textbox,
            id = "text_role",
            text = wp.text
        }
    })

    capi.tag.connect_signal("property::selected", function()
        if wp.unfocus_on_tag_change then
            widget:unfocus()
        end
    end)

    capi.awesome.connect_signal("text_input::focus", function(text_input)
        if wp.unfocus_on_other_text_input_focus and text_input ~= widget then
            widget:unfocus()
        end
    end)

    capi.client.connect_signal("focus", function()
        if wp.unfocus_on_client_focus then
            widget:unfocus()
        end
    end)

    awful.mouse.append_global_mousebindings({
        awful.button({"Any"}, 1, function()
            if wp.unfocus_on_root_clicked then
                widget:unfocus()
            end
        end),
        awful.button({"Any"}, 3, function()
            if wp.unfocus_on_root_clicked then
                widget:unfocus()
            end
        end)
    })

    capi.client.connect_signal("button::press", function()
        if wp.unfocus_on_client_clicked then
            widget:unfocus()
        end
    end)

    return widget
end

function text_input.mt:__call(...)
    return new(...)
end

build_properties(text_input, properties)

return setmetatable(text_input, text_input.mt)
