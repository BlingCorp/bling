local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local beautiful = require("beautiful")
local menu_gen   = require("menubar.menu_gen")
local dpi = beautiful.xresources.apply_dpi

-- =============================================================================
--  Customization
-- =============================================================================
local app_normal_color = beautiful.xcolor0
local app_selected_color = beautiful.xcolor8
local grid_margin = dpi(30)
local grid_spacing = dpi(30)
local item_width = dpi(200)
local forced_num_rows = 3
local forced_num_cols = 5
local prompt_text = "<b>Search</b>: "
local prompt_cursor_bg = beautiful.xcolor0
local prompt_start_text = ""

-- =============================================================================
--  Locals
-- =============================================================================
local grid_width = dpi(item_width * forced_num_cols + grid_margin + grid_spacing)
local all_entries = {}
local matched_entries = {}
local apps_per_page = forced_num_cols * forced_num_rows
local apps_on_last_page = 0
local pages_count = 0
local current_index = 1
local current_page = 1

-- =============================================================================
--  UI
-- =============================================================================
local shell = awful.widget.prompt{bg = "#00000000", fg = beautiful.xcolor0, font = beautiful.font_name .. "Bold 15"}
local final_widget
local grid

local create_app = function(name, cmdline, icon, index)
    local button = wibox.widget
    {
        widget = wibox.container.background,
        id = "background",
        shape = gears.shape.rounded_rect,
        bg = app_normal_color,
        spawn = function() awful.spawn(cmdline) end,
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

    button:buttons(gears.table.join(awful.button({}, 1, function()
        if index == current_index then
            awful.spawn(cmdline)
            root.fake_input('key_press', "Escape")
            root.fake_input('key_release', "Escape")
        else
            grid.children[current_index]:get_children_by_id("background")[1].bg = app_normal_color
            current_index = index
            grid.children[current_index]:get_children_by_id("background")[1].bg = app_selected_color
        end
    end)))

    return button
end

menu_gen.generate(function(entries)
    table.sort(entries, function(a, b) return a.name:lower() < b.name:lower() end)
    for k, v in pairs(entries) do
        table.insert(all_entries, k, { name = v.name, cmdline = v.cmdline, icon = v.icon })
        grid:add(create_app(v.name, v.cmdline, v.icon, k))
    end
    matched_entries = all_entries
    apps_on_last_page = #all_entries % apps_per_page
    pages_count = math.ceil(#all_entries / apps_per_page)
    grid.children[1]:get_children_by_id("background")[1].bg = app_selected_color
end)

-- =============================================================================
--  Prompt
-- =============================================================================
local search = function(command)
    local case_insensitive_pattern = function(pattern)
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

    if grid.children[current_index] ~= nil then
        grid.children[current_index]:get_children_by_id("background")[1].bg = app_normal_color
    end

    grid:reset()

    matched_entries = {}
    for k, v in pairs(all_entries) do
        command = command:gsub( "%W", "" )
        if string.find(v.name, case_insensitive_pattern(command)) ~= nil then
            grid:add(create_app(v.name, v.cmdline, v.icon, k))
            table.insert(matched_entries, #matched_entries + 1, { name = v.name, cmdline = v.cmdline, icon = v.icon })
        end
    end

    apps_per_page = math.min(#matched_entries, forced_num_cols * forced_num_rows)
    pages_count = math.ceil(math.max(1, #matched_entries) / math.max(1, apps_per_page))
    if pages_count <=1 then
        apps_on_last_page = apps_per_page
    else
        apps_on_last_page = #matched_entries % apps_per_page
    end

    current_page = 1
    current_index = 1

    if grid.children[current_index] ~= nil then
        grid.children[1]:get_children_by_id("background")[1].bg = app_selected_color
    end
end

local select_or_spawn = function(mod, key, cmd)
    if key == 'Return' then
        grid.children[current_index].spawn()
    end
end

local exit = function()
    apps_per_page = forced_num_cols * forced_num_rows
    apps_on_last_page = #all_entries % apps_per_page
    pages_count = math.ceil(#all_entries / apps_per_page)
    matched_entries = all_entries
    current_index = 1
    current_page = 1
    final_widget.visible = false
    grid:reset()
    for k, v in pairs(all_entries) do
        grid:add(create_app(v.name, v.cmdline, v.icon, k))
    end
end

local prompt = function()
    awful.prompt.run
    {
        prompt = prompt_text,
        bg_cursor = prompt_cursor_bg,
        textbox = shell.widget,
        text = prompt_start_text,
        changed_callback = search,
        keypressed_callback = select_or_spawn,
        done_callback = exit
    }
end

-- =============================================================================
--  Grid
-- =============================================================================
local scroll_up = function()
    if current_index > 1 then
        grid.children[current_index]:get_children_by_id("background")[1].bg = app_normal_color
        current_index = current_index - 1
        grid.children[current_index]:get_children_by_id("background")[1].bg = app_selected_color
    elseif current_page > 1 then
        grid:reset()
        current_index = apps_per_page
        for k, v in pairs(all_entries) do
            if k <= (current_index * current_page) and k > (current_index * (current_page - 2)) then
                grid:add(create_app(v.name, v.cmdline, v.icon, k))
            end
        end
        current_page = current_page - 1
        grid.children[current_index]:get_children_by_id("background")[1].bg = app_selected_color
    end
end

local scroll_down  = function()
  if current_index < apps_per_page and current_page < pages_count or
        current_index < apps_on_last_page and current_page == pages_count
    then
        grid.children[current_index]:get_children_by_id("background")[1].bg = app_normal_color
        current_index = current_index + 1
        grid.children[current_index]:get_children_by_id("background")[1].bg = app_selected_color
    elseif current_page < pages_count then
        grid:reset()
        for k, v in pairs(matched_entries) do
            if k >= (current_index * current_page) + 1 then
                grid:add(create_app(v.name, v.cmdline, v.icon, k))
            end
        end
        current_index = 1
        current_page = current_page + 1
        grid.children[current_index]:get_children_by_id("background")[1].bg = app_selected_color
    end
end

grid = wibox.widget
{
    layout = wibox.layout.grid,
    orientation = "horizontal",
    forced_num_rows = forced_num_rows,
    homogeneous     = true,
    expand          = false,
    forced_width = grid_width,
    -- forced_height = dpi(650),
    spacing = dpi(30),
    buttons = gears.table.join
    (
        -- Scroll up
        awful.button({}, 4, function() scroll_up() end),
        -- Scroll down
        awful.button({}, 5, function() scroll_down() end)
    )
}

-- =============================================================================
--  Final widget
-- =============================================================================
final_widget = awful.popup
({
    screen = screen.primary,
    placement = awful.placement.centered,
    shape = gears.shape.rounded_rect,
    type = "dock",
    bg =  beautiful.xcolor0,
    visible = false,
    ontop = true,
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
                shell
            }
        },
        {
            widget = wibox.container.margin,
            margins = dpi(30),
            grid
        }
    }
})

awesome.connect_signal("bling::app_launcher::visibility", function(v)
    final_widget.visible = v
    if v then
        prompt()
    end
end)