local gtable = require("gears.table")
local gtimer = require("gears.timer")
local wibox = require("wibox")
local ipairs = ipairs
local table = table
local math = math

local rofi_grid  = { mt = {} }

local properties = {
    "entries", "page", "lazy_load_widgets",
    "widget_template", "entry_template",
    "sort_fn", "search_fn", "search_sort_fn",
    "sort_alphabetically","reverse_sort_alphabetically,",
    "wrap_page_scrolling", "wrap_entry_scrolling"
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

local function scroll(self, dir, page_dir)
    local grid = self:get_grid()
    if #grid.children < 1 then
        self._private.selected_widget = nil
        return
    end

    local next_widget_index = nil
    local grid_orientation = grid:get_orientation()

    if dir == "up" then
        if grid_orientation == "horizontal" then
            next_widget_index = grid:index(self:get_selected_widget()) - 1
        elseif grid_orientation == "vertical" then
            next_widget_index = grid:index(self:get_selected_widget()) - grid.forced_num_cols
        end
    elseif dir == "down" then
        if grid_orientation == "horizontal" then
            next_widget_index = grid:index(self:get_selected_widget()) + 1
        elseif grid_orientation == "vertical" then
            next_widget_index = grid:index(self:get_selected_widget()) + grid.forced_num_cols
        end
    elseif dir == "left" then
        if grid_orientation == "horizontal" then
            next_widget_index = grid:index(self:get_selected_widget()) - grid.forced_num_rows
        elseif grid_orientation == "vertical" then
            next_widget_index = grid:index(self:get_selected_widget()) - 1
        end
    elseif dir == "right" then
        if grid_orientation == "horizontal" then
            next_widget_index = grid:index(self:get_selected_widget()) + grid.forced_num_rows
        elseif grid_orientation == "vertical" then
            next_widget_index = grid:index(self:get_selected_widget()) + 1
        end
    end

    local next_widget = grid.children[next_widget_index]
    if next_widget then
        next_widget:select()
        self:emit_signal("scroll", self:get_index_of_widget(next_widget))
    else
        if dir == "up" or dir == "left" then
            self:page_backward(page_dir or dir)
        elseif dir == "down" or dir == "right" then
            self:page_forward(page_dir or dir)
        end
    end
end

local function entry_widget(self, entry)
    if self._private.entries_widgets_cache[entry] then
        return self._private.entries_widgets_cache[entry]
    end

    local widget = self._private.entry_template(entry, self)

    local rofi_grid = self
    function widget:select()
        rofi_grid:select_widget(self)
    end

    function widget:is_selected()
        return rofi_grid:get_selected_widget() == self
    end

    entry.widget = widget
    widget.entry = entry

    self._private.entries_widgets_cache[entry] = widget
    return widget
end

function rofi_grid:set_widget_template(widget_template)
    self._private.text_input = widget_template:get_children_by_id("text_input_role")[1]
    self._private.grid = widget_template:get_children_by_id("grid_role")[1]
    self._private.scrollbar = widget_template:get_children_by_id("scrollbar_role")
    if self._private.scrollbar then
        self._private.scrollbar = self._private.scrollbar[1]
    end

    widget_template:connect_signal("button::press", function(_, lx, ly, button, mods, find_widgets_result)
        if button == 4 then
            if self:get_grid():get_orientation() == "horizontal" then
                self:scroll_up()
            else
                self:scroll_left("up")
            end
        elseif button == 5 then
            if self:get_grid():get_orientation() == "horizontal" then
                self:scroll_down()
            else
                self:scroll_right("down")
            end
        end
    end)

    self:get_text_input():connect_signal("property::text", function(_, text)
        if text == self:get_text() then
            return
        end

        self._private.text = text
        self._private.search_timer:again()
    end)

    self:get_text_input():connect_signal("key::release", function(_, mod, key, cmd)
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

    local scrollbar = self:get_scrollbar()
    if scrollbar then
        self:connect_signal("scroll", function(self, new_index)
            scrollbar:set_value(new_index)
        end)

        self:connect_signal("page::forward", function(self, new_index)
            scrollbar:set_value(new_index)
        end)

        self:connect_signal("page::backward", function(self, new_index)
            scrollbar:set_value(new_index)
        end)

        self:connect_signal("search", function(self, text, new_index)
            scrollbar:set_maximum(math.max(2, #self:get_matched_entries()))
            if new_index then
                scrollbar:set_value(new_index)
            end
        end)

        self:connect_signal("select", function(self, new_index)
            scrollbar:set_value(new_index)
        end)

        scrollbar:connect_signal("property::value", function(_, value, instant)
            if instant ~= true then
                self:select_widget_by_index(value)
            end
        end)
    end

    self._private.max_entries_per_page = self:get_grid().forced_num_cols * self:get_grid().forced_num_rows
    self._private.entries_per_page = self._private.max_entries_per_page

    self:set_widget(widget_template)
end

function rofi_grid:set_entries(entries, sort_fn)
    self._private.entries = entries
    self:set_sort_fn(sort_fn)
    self:reset()
    local scrollbar = self:get_scrollbar()
    if scrollbar then
        scrollbar:set_maximum(#self._private.entries)
        scrollbar:set_value(1)
    end

    if self._private.lazy_load_widgets == false then
        for _, entry in ipairs(self._private.entries) do
            self._private.entries_widgets_cache[entry] = entry_widget(self, entry)
        end
    end
end

function rofi_grid:add_entry(entry)
    table.insert(self._private.entries, entry)
    self:set_sort_fn()
    self:reset()
end

function rofi_grid:set_sort_fn(sort_fn)
    if sort_fn ~= nil then
        self._private.sort_fn = sort_fn
    end
    if self._private.sort_fn ~= nil then
        table.sort(self._private.entries, self._private.sort_fn)
    end
end

function rofi_grid:refresh()
    local max_entry_index_to_include = self._private.entries_per_page * self:get_current_page()
    local min_entry_index_to_include = max_entry_index_to_include - self._private.entries_per_page

    self:get_grid():reset()

    for index, entry in ipairs(self:get_matched_entries()) do
        -- Only add widgets that are between this range (part of the current page)
        if index > min_entry_index_to_include and index <= max_entry_index_to_include then
            self:get_grid():add(entry_widget(self, entry))
        end
    end
end

function rofi_grid:search()
    local text = self:get_text()
    local old_pos = self:get_grid():get_widget_position(self:get_selected_widget())

    -- Reset all the matched entrys
    self._private.matched_entries = {}
    -- Remove all the grid widgets
    self:get_grid():reset()

    if text == "" then
        self._private.matched_entries = self._private.entries
    else
        for _, entry in ipairs(self._private.entries) do
            text = text:gsub( "%W", "" )
            if self.search_fn(text:lower(), entry, self:get_entries()) then
                table.insert(self:get_matched_entries(), entry)
            end
        end

        if self:get_sort_fn() then
            table.sort(self:get_matched_entries(), function(a, b)
                return self._private.search_sort_fn(text, a, b)
            end)
        end
    end
    for _, entry in ipairs(self._private.matched_entries) do
        -- Only add the widgets for entrys that are part of the first page
        if #self:get_grid().children + 1 <= self._private.max_entries_per_page then
            self:get_grid():add(entry_widget(self, entry))
        end
    end

    -- Recalculate the entrys per page based on the current matched entrys
    self._private.entries_per_page = math.min(#self:get_matched_entries(), self._private.max_entries_per_page)

    -- Recalculate the pages count based on the current entrys per page
    self._private.pages_count = math.ceil(math.max(1, #self:get_matched_entries()) / math.max(1, self._private.entries_per_page))

    -- Page should be 1 after a search
    self._private.current_page = 1

    -- This is an option to mimic rofi behaviour where after a search
    -- it will reselect the entry whose index is the same as the entry index that was previously selected
    -- and if matched_entries.length < current_index it will instead select the entry with the greatest index
    if self._private.try_to_keep_index_after_searching then
        local widget_at_old_pos = self:get_grid():get_widgets_at(old_pos.row, old_pos.col)
        if widget_at_old_pos and widget_at_old_pos[1] then
            widget_at_old_pos[1]:select()
        else
            local widget = self:get_grid().children[#self:get_grid().children]
            widget:select()
        end
    -- Otherwise select the first entry on the list
    elseif self:get_grid().children[1] then
        local widget = self:get_grid().children[1]
        widget:select()
    end

    self:emit_signal("search", self:get_text(), self:get_index_of_widget(self:get_selected_widget()))
end

function rofi_grid:select_widget(widget)
    print(widget)
    self:select_widget_by_index(self:get_index_of_widget(widget))
end

function rofi_grid:select_widget_by_index(index)
    local previous_widget = self:get_selected_widget()
    if previous_widget then
        self._private.selected_widget = nil
        self:emit_signal("unselect")
        previous_widget:emit_signal("unselect")
    end

    print(index)

    -- local new_widget = self:get_widget_of_index(index)
    -- if new_widget then
    --     local page = self:get_page_of_index(index)
    --     if self:get_current_page() ~= page then
    --         self:set_page(page)
    --     end

    --     self._private.selected_widget = new_widget
    --     self:emit_signal("select", index)
    --     new_widget:emit_signal("select", index)
    -- end
end

function rofi_grid:scroll_up(page_dir)
    scroll(self, "up", page_dir)
end

function rofi_grid:scroll_down(page_dir)
    scroll(self, "down", page_dir)
end

function rofi_grid:scroll_left(page_dir)
    scroll(self, "left", page_dir)
end

function rofi_grid:scroll_right(page_dir)
    scroll(self, "right", page_dir)
end

function rofi_grid:page_forward(dir)
    local min_entry_index_to_include = 0
    local max_entry_index_to_include = self._private.entries_per_page

    if self:get_current_page() < self:get_pages_count() then
        min_entry_index_to_include = self._private.entries_per_page * self:get_current_page()
        self._private.current_page = self:get_current_page() + 1
        max_entry_index_to_include = self._private.entries_per_page * self:get_current_page()
    elseif self._private.wrap_page_scrolling and #self:get_matched_entries() >= self._private.max_entries_per_page then
        self._private.current_page = 1
        min_entry_index_to_include = 0
        max_entry_index_to_include = self._private.entries_per_page
    elseif self._private.wrap_entry_scrolling then
        local widget = self:get_grid():get_widgets_at(1, 1)[1]
        widget:select()
        self:emit_signal("scroll", self:get_index_of_widget(widget))
        return
    else
        return
    end

    local pos = self:get_grid():get_widget_position(self:get_selected_widget())

    -- Remove the current page entrys from the grid
    self:get_grid():reset()

    for index, entry in ipairs(self:get_matched_entries()) do
        -- Only add widgets that are between this range (part of the current page)
        if index > min_entry_index_to_include and index <= max_entry_index_to_include then
            self:get_grid():add(entry_widget(self, entry))
        end
    end

    if self:get_current_page() > 1 or self._private.wrap_page_scrolling then
        local widget = nil
        if dir == "down" then
            widget = self:get_grid():get_widgets_at(1, 1)[1]
        elseif dir == "right" then
            widget = self:get_grid():get_widgets_at(pos.row, 1)
            if widget then
                widget = widget[1]
            end
            if widget == nil then
                widget = self:get_grid().children[#self:get_grid().children]
            end
        end
        widget:select()
    end

    self:emit_signal("page::forward", self:get_index_of_widget(self:get_selected_widget()))
end

function rofi_grid:page_backward(dir)
    if self:get_current_page() > 1 then
        self._private.current_page = self:get_current_page() - 1
    elseif self._private.wrap_page_scrolling and #self:get_matched_entries() >= self._private.max_entries_per_page then
        self._private.current_page = self:get_pages_count()
    elseif self._private.wrap_entry_scrolling then
        local widget = self:get_grid().children[#self:get_grid().children]
        widget:select()
        self:emit_signal("scroll", self:get_index_of_widget(widget))
        return
    else
        return
    end

    local pos = self:get_grid():get_widget_position(self:get_selected_widget())

    -- Remove the current page entrys from the grid
    self:get_grid():reset()

    local max_entry_index_to_include = self._private.entries_per_page * self:get_current_page()
    local min_entry_index_to_include = max_entry_index_to_include - self._private.entries_per_page

    for index, entry in ipairs(self:get_matched_entries()) do
        -- Only add widgets that are between this range (part of the current page)
        if index > min_entry_index_to_include and index <= max_entry_index_to_include then
            self:get_grid():add(entry_widget(self, entry))
        end
    end

    local widget = nil
    if self:get_current_page() < self:get_pages_count() then
        if dir == "up" then
            widget = self:get_grid().children[#self:get_grid().children]
        else
            -- Keep the same row from last page
            local _, columns = self:get_grid():get_dimension()
            widget = self:get_grid():get_widgets_at(pos.row, columns)[1]
        end
    elseif self._private.wrap_page_scrolling then
        widget = self:get_grid().children[#self:get_grid().children]
    end
    widget:select()

    self:emit_signal("page::backward", self:get_index_of_widget(self:get_selected_widget()))
end

function rofi_grid:set_page(page)
    self:get_grid():reset()
    self._private.matched_entries = self._private.entries
    self._private.entries_per_page = self._private.max_entries_per_page
    self._private.pages_count = math.ceil(#self._private.entries / self._private.entries_per_page)
    self._private.current_page = page

    local max_entry_index_to_include = self._private.entries_per_page * self:get_current_page()
    local min_entry_index_to_include = max_entry_index_to_include - self._private.entries_per_page

    for index, entry in ipairs(self:get_matched_entries()) do
        -- Only add widgets that are between this range (part of the current page)
        if index > min_entry_index_to_include and index <= max_entry_index_to_include then
            self:get_grid():add(entry_widget(self, entry))
        end
    end

    local widget = self:get_grid():get_widgets_at(1, 1)
    if widget then
        widget = widget[1]
        if widget then
            widget:select()
        end
    end
end

function rofi_grid:reset()
    self:get_grid():reset()
    self._private.matched_entries = self._private.entries
    self._private.entries_per_page = self._private.max_entries_per_page
    self._private.pages_count = math.ceil(#self._private.entries / self._private.entries_per_page)
    self._private.current_page = 1

    for index, entry in ipairs(self._private.entries) do
        -- Only add the entrys that are part of the first page
        if index <= self._private.entries_per_page then
            self:get_grid():add(entry_widget(self, entry))
        else
            break
        end
    end

    local widget = self:get_grid():get_widgets_at(1, 1)
    if widget then
        widget = widget[1]
        if widget then
            widget:select()
        end
    end

    self:get_text_input():set_text("")
end

function rofi_grid:get_scrollbar()
    return self._private.scrollbar
end

function rofi_grid:get_text_input()
    return self._private.text_input
end

function rofi_grid:get_grid()
    return self._private.grid
end

function rofi_grid:get_entries_per_page()
    return self._private.entries_per_page
end

function rofi_grid:get_pages_count()
    return self._private.pages_count
end

function rofi_grid:get_current_page()
    return self._private.current_page
end

function rofi_grid:get_entries()
    return self._private.entries
end

function rofi_grid:get_matched_entries()
    return self._private.matched_entries
end

function rofi_grid:get_page_of_index(index)
    return math.floor((index - 1) / self._private.entries_per_page) + 1
end

function rofi_grid:get_index_of_widget(widget)
    for index, matched_widget in ipairs(self:get_matched_entries()) do
        if matched_widget.entry == widget.entry then
            return index
        end
    end
end

function rofi_grid:get_widget_of_index(index)
    return self:get_matched_entries()[index].widget
end

function rofi_grid:get_text()
    return self._private.text
end

function rofi_grid:get_selected_widget()
    return self._private.selected_widget
end

local function new()
    local widget = wibox.container.background()
    gtable.crush(widget, rofi_grid, true)

    local wp = widget._private
    wp.entries_widgets_cache = setmetatable({}, { __mode = "v" })

    wp.entries = {}
    wp.sort_fn = nil
    wp.sort_alphabetically = true
    wp.reverse_sort_alphabetically = false
    wp.try_to_keep_index_after_searching = false
    wp.wrap_page_scrolling = true
    wp.wrap_entry_scrolling = true
    wp.search_fn = nil
    wp.lazy_load_widgets = true

    wp.text = ""
    wp.pages_count = 0
    wp.current_page = 1
    wp.search_timer = gtimer {
        timeout = 0.35,
        call_now = false,
        autostart = false,
        single_shot = true,
        callback = function()
            widget:search()
        end
    }

    return widget
end

function rofi_grid.mt:__call(...)
    return new(...)
end

build_properties(rofi_grid, properties)

return setmetatable(rofi_grid, rofi_grid.mt)
