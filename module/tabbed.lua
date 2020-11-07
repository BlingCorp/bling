--[[
WORK IN PROGRESS

This module currently works by adding a new property to each client that is tabbed.
That new property is called bling_tabbed. 
So each client in a tabbed state has the property "bling_tabbed" which is a table.
Each client that is not tabbed doesn't have that property.
In the function themselves, the same object is refered to as "tabobj" which is why
you will often see something like: "local tabobj = some_client.bling_tabbed" at the beginning
of a function.

The tabobj (or the bling_tabbed property - essentially two names for the same thing) 
is a table with two entries: clients (a list of clients that are tabbed) and
focused_idx (the index of the client in the tabobj.clients list that is currently focused).
(New properties might be added as needed)

To "make clients disappear and reappear" this module uses the functions in the helper module.

There are the following functions:
tabbed.init: Initalizes a tabobj (or a client.bling_tabbed) on the currently focused client
tabbed.add: Adds a new client to an existing focused tabbed client via xprop selection (calls tabbed.init if there is no tabobj)
tabbed.remove: Removes the currently focused client from it's tabbed accumulation
tabbed.switch_to: Switches focus of a given tabobj by a given difference
tabbed.update: Takes a tabobj, updates all bling_tabbed properties and calls update_tabbar 
tabbed.update_tabbar: updates the tabbar of the tabobj that is given as an arg
tabbed.iter: Iterate though all tabs analogous to awful.focus.byidx(1) 
copy_size: Should copy the size, position and so on onto another client

To use that module you would have to add the tabbed.add and the tabbed.remove function as keybindings

TODO
The following features have to be implemented:
- consitent layout: When using a tiled layout and switching between different tabs, the place of the whole
tabbed thingy changes
- maybe for easy extensability, split functions like tabbed.remove, tabbed.add etc into two: one which 
takes a client as an argument and another which just calls the function with client.focus as an argument. Might 
be important for adding better tab bar support later on (for example closing windows from the tabbar)
--]]

local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")

local beautiful = require("beautiful")

local helpers = require(tostring(...):match(".*bling.module") .. ".helpers")


local bg_normal = beautiful.tabbed_bg_normal or beautiful.bg_normal or "#ffffff"
local fg_normal = beautiful.tabbed_fg_focus  or beautiful.fg_normal or "#000000"
local bg_focus  = beautiful.tabbed_bg_focus  or beautiful.bg_focus  or "#000000"
local fg_focus  = beautiful.tabbed_fg_focus  or beautiful.fg_focus  or "#ffffff"
local font      = beautiful.tabbed_font      or beautiful.font      or "Hack 15"

local function copy_size(c, parent_client)
    if not c or not parent_client then
        return
    end
    if not c.valid or not parent_client.valid then
        return
    end
    c.floating = parent_client.floating
    c.x = parent_client.x
    c.y = parent_client.y
    c.width = parent_client.width
    c.height = parent_client.height
end

tabbed = {}

tabbed.iter = function(idx)
    if not client.focus.bling_tabbed then return end 
    local tabobj = client.focus.bling_tabbed
    local new_idx = (tabobj.focused_idx + idx) % #tabobj.clients
    if new_idx == 0 then 
        new_idx = #tabobj.clients
    end
    tabbed.switch_to(tabobj, new_idx)
end 

tabbed.remove = function()
    if not client.focus.bling_tabbed then return end
    local tabobj = client.focus.bling_tabbed
    table.remove(client.focus.bling_tabbed.clients, tabobj.focused_idx)
    awful.titlebar.hide(client.focus)
    client.focus.bling_tabbed = nil
    tabbed.switch_to(tabobj, 1)
end 

tabbed.add = function()
    if not client.focus.bling_tabbed then tabbed.init() end
    local tabobj = client.focus.bling_tabbed
    -- this function uses xprop to grab a client pid which is then 
    -- compared to all other client process ids
    -- io.popen is normally discouraged. Works fine for now 
    local handle = io.popen("xprop _NET_WM_PID | cut -d' ' -f3")
    local output = handle:read("*a")
    handle:close()
    for _,c in ipairs(client.get()) do
        if tonumber(c.pid) == tonumber(output) then
            if c.bling_tabbed then return end 
            tabobj.clients[#tabobj.clients+1] = c
            tabobj.focused_idx = #tabobj.clients
            copy_size(c, client.focus)
        end 
    end 
    tabbed.switch_to(tabobj, #tabobj.clients)
end

tabbed.update = function(tabobj) 
    local currently_focused_c = tabobj.clients[tabobj.focused_idx]
    for idx,c in ipairs(tabobj.clients) do 
        c.bling_tabbed = tabobj
        copy_size(c, currently_focused_c)
    end 
    tabbed.update_tabbar(tabobj)
end

tabbed.switch_to = function(tabobj, new_idx)
    local old_focused_c = tabobj.clients[tabobj.focused_idx]
    tabobj.focused_idx = new_idx
    for idx,c in ipairs(tabobj.clients) do 
        if idx ~= new_idx then 
            helpers.turn_off(c)
        else  
            helpers.turn_on(c)
            c:raise()
            copy_size(c, old_focused_c)
        end 
    end 
    tabbed.update(tabobj)
end

tabbed.update_tabbar = function(tabobj)
    local flexlist = wibox.layout.flex.horizontal()
    -- itearte over all tabbed clients to create the widget tabbed list
    for idx,c in ipairs(tabobj.clients) do 
        local title_temp = c.name or c.class
        local bg_temp = bg_normal
        local fg_temp = fg_normal
        if idx == tabobj.focused_idx then
            bg_temp = bg_focus 
            fg_temp = fg_focus
        end
        local buttons = gears.table.join(awful.button({}, 1, function()
            tabbed.switch_to(tabobj, idx) 
        end))
        local text_temp = wibox.widget.textbox()
        text_temp.align = "center"
        text_temp.valign = "center"
        text_temp.font = font
        text_temp.markup = "<span foreground='" .. fg_temp .. "'>" .. title_temp.. "</span>"
        local wid_temp = wibox.widget({
            text_temp,
            buttons = buttons,
            bg = bg_temp,
            widget = wibox.container.background()
        })
        flexlist:add(wid_temp)
    end 
    -- add tabbar to each tabbed client (clients will be hided anyway)
    for _,c in ipairs(tabobj.clients) do 
        local titlebar = awful.titlebar(c, {
            height = 20,
            position = "top"
        })
        titlebar:setup {
            layout = wibox.layout.flex.horizontal,
            flexlist,
        }
    end 
end 

tabbed.init = function(c)
    if not client.focus.bling_tabbed then 
        local tabobj = {}
        tabobj.clients = {client.focus}
        tabobj.focused_idx = 1
        tabbed.switch_to(tabobj, 1)
    end
end

return tabbed
