--[[

This module currently works by adding a new property to each client that is tabbed.
That new property is called tab_obj.
So each client in a tabbed state has the property "tab_obj" which is a table.
Each client that is not tabbed doesn't have that property.
In the function themselves, the same object is refered to as "tabobj" which is why
you will often see something like: "local tabobj = some_client.tab_obj" at the beginning
of a function.

--]]

local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local beautiful = require("beautiful")
local helpers = require(tostring(...):match(".*bling") .. ".helpers")

local bar_style = beautiful.tabbar_style or "default"
local bar = require(tostring(...):match(".*bling") .. ".widget.tabbar." ..
                        bar_style)

tabbed = {}

local get_tab_buttons = function(c)
    return gears.table.join(
        awful.button(
            {}, 1,
            function()
                local tabobj = c.tab_obj
                tabbed.switch_to(tabobj, c.tab_idx)
                c.move_timer = gears.timer({
                    timeout = 0.3,
                    callback = function()
                        awful.mouse.client.move(c)
                        c.move_timer = nil
                    end,
                    single_shot = true,
                })
                c.move_timer:start()
            end,
            function()
                if (c.move_timer) then
                    c.move_timer:stop()
                    c.move_timer = nil
                end
            end
        ),
        awful.button({}, 2, tabbed.pop),
        awful.button({}, 3,
            function()
                local tabobj = c.tab_obj
                tabbed.switch_to(tabobj, c.tab_idx)
                c.resize_timer = gears.timer({
                    timeout = 0.3,
                    callback = function()
                        awful.mouse.client.resize(c)
                        c.resize_timer = nil
                    end,
                    single_shot = true,
                })
                c.resize_timer:start()
            end,
            function()
                if (c.resize_timer) then
                    c.resize_timer:stop()
                    c.resize_timer = nil
                end
            end
        )
    )
end

-- used to change focused tab relative to the currently focused one
tabbed.iter = function(idx)
    if not idx then idx = 1 end
    if not client.focus or not client.focus.tab_obj then return end
    local tabobj = client.focus.tab_obj
    local new_idx = (tabobj.focused_idx + idx) % #tabobj.clients
    if new_idx == 0 then new_idx = #tabobj.clients end
    tabbed.switch_to(tabobj, new_idx)
end

-- removes a given client from its tab object
tabbed.remove = function(c)
    if not c or not c.bling_tabbed then return end
    local tabobj = c.bling_tabbed
    table.remove(tabobj.clients, tabobj.focused_idx)
    if not beautiful.tabbar_disable then
        awful.titlebar.hide(c, bar.position)
    end
    c.bling_tabbed = nil
    tabbed.switch_to(tabobj, 1)
end

-- removes the currently focused client from the tab object
tabbed.pop = function()
    if not client.focus or not client.focus.tab_obj then return end
    tabbed.remove(client.focus)
end

-- adds a client to a given tabobj
tabbed.add = function(c, tabobj)
    if c.bling_tabbed then
        tabbed.remove(c)
    end
    helpers.client.sync(c, tabobj.clients[tabobj.focused_idx])
    local index = #tabobj.clients + 1
    c.tab_idx = index
    tabobj.clients[index] = c
    tabobj.focused_idx = #tabobj.clients
    -- calls update even though switch_to calls update again
    -- but the new client needs to have the tabobj property
    -- before a clean switch can happen
    tabbed.update(tabobj)
    awesome.emit_signal("bling::tabbed::client_added", tabobj)
    tabbed.switch_to(tabobj, #tabobj.clients)
end

-- use xwininfo to select one client and make it tab in the currently focused tab
tabbed.pick = function()
    if not client.focus then return end
    -- this function uses xwininfo to grab a client window id which is then
    -- compared to all other clients window ids

    local xwininfo_cmd = [[ xwininfo | grep 'xwininfo: Window id:' | cut -d " " -f 4 ]]
    awful.spawn.easy_async_with_shell(xwininfo_cmd, function(output)
        for _, c in ipairs(client.get()) do
            if tonumber(c.window) == tonumber(output) then
                if client.focus == c then return end
                if not client.focus.tab_obj and not c.tab_obj then
                    tabbed.init(c)
                    tabbed.add(client.focus, c.tab_obj)
                end
                if client.focus.tab_obj and not c.tab_obj then
                    tabbed.add(c, client.focus.tab_obj)
                end
                if not client.focus.tab_obj and c.tab_obj then
                    tabbed.add(client.focus, c.tab_obj)
                end
            end
        end
    end)
end

-- select a client by direction and make it tab in the currently focused tab
tabbed.pick_by_direction = function(direction) 
    local sel = client.focus
    if not sel then return end
    if not sel.bling_tabbed then tabbed.init(sel) end
    local c = helpers.client.get_by_direction(direction)
    if not c then return end
    tabbed.add(c, sel.bling_tabbed)
end

-- use dmenu to select a client and make it tab in the currently focused tab 
tabbed.pick_with_dmenu = function(dmenu_command)
    if not client.focus then return end

    if not dmenu_command then dmenu_command = "rofi -dmenu -i" end

    -- get all clients from the current tag
    -- ignores the case where multiple tags are selected
    local t = awful.screen.focused().selected_tag
    local list_clients = {}
    local list_clients_string = ""
    for idx, c in ipairs(t:clients()) do
        if c.window ~= client.focus.window then
            list_clients[#list_clients + 1] = c
            if #list_clients ~= 1 then
                list_clients_string = list_clients_string .. "\\n"
            end
            list_clients_string = list_clients_string .. tostring(c.window) ..
                " " .. c.name
        end
    end

    if #list_clients == 0 then return end
    -- calls the actual dmenu
    local xprop_cmd = [[ echo -e "]] .. list_clients_string .. [[" | ]] ..
        dmenu_command .. [[ | awk '{ print $1 }' ]]
    awful.spawn.easy_async_with_shell(xprop_cmd, function(output)
        for _, c in ipairs(list_clients) do
            if tonumber(c.window) == tonumber(output) then
                if not client.focus.bling_tabbed then tabbed.init(client.focus) end
                local tabobj = client.focus.bling_tabbed
                tabbed.add(c, tabobj)
            end
        end
    end)
end

-- update everything about one tab object
tabbed.update = function(tabobj)
    local currently_focused_c = tabobj.clients[tabobj.focused_idx]
    -- update tabobj of each client and other things
    for idx, c in ipairs(tabobj.clients) do
        if c.valid then
            c.tab_idx = idx
            c.tab_obj = tabobj
            helpers.client.sync(c, currently_focused_c)
            -- the following handles killing a client while the client is tabbed
            c:connect_signal("unmanage", function(c) tabbed.remove(c) end)
        end
    end

    awesome.emit_signal("bling::tabbed::update", tabobj)
    if not beautiful.tabbar_disable then 
        tabbed.update_tabbar(tabobj)
    end
end

-- change focused tab by absolute index
tabbed.switch_to = function(tabobj, new_idx)
    local old_focused_c = tabobj.clients[tabobj.focused_idx]
    tabobj.focused_idx = new_idx
    for idx, c in ipairs(tabobj.clients) do
        if idx ~= new_idx then
            helpers.client.turn_off(c)
        else
            helpers.client.turn_on(c)
            c:raise()
            if old_focused_c and old_focused_c.valid then
                c:swap(old_focused_c)
            end
            helpers.client.sync(c, old_focused_c)
        end
    end
    tabbed.update(tabobj)
end

tabbed.update_tabbar = function(tabobj)
    local tabslist = bar.layout()
    -- itearte over all tabbed clients to create the widget tabbed list
    for idx, c in ipairs(tabobj.clients) do
        local buttons = get_tab_buttons(c)
        wid_temp = bar.create(c, (idx == tabobj.focused_idx), buttons)
        tabslist:add(wid_temp)
        -- add tabbar to each tabbed client (clients will be hided anyway)
        local titlebar = awful.titlebar(c, {
            bg = bar.bg_normal,
            size = bar.size,
            position = bar.position
        })
        titlebar:setup{layout = bar.layout, tabslist}
    end
end

tabbed.init = function(c)
    local tabobj = {}
    tabobj.clients = {c}
    tabobj.focused_idx = 1
    tabbed.update(tabobj)
end

if beautiful.tabbed_spawn_in_tab then
    client.connect_signal("manage", function(c)
        local s = awful.screen.focused()
        local previous_client = awful.client.focus.history.get(s, 1)
        if previous_client and previous_client.tab_obj then
            tabbed.add(c, previous_client.tab_obj)
        end
    end)
end

return tabbed
