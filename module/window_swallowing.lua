local awful = require("awful")
local gears = require("gears")
local beautiful = require("beautiful")

local helpers = require(tostring(...):match(".*bling") .. ".helpers")

-- It might actually swallow too much, that's why there is a filter option by classname
-- without the don't-swallow-list it would also swallow for example
-- file pickers or new firefox windows spawned by an already existing one

local window_swallowing_activated = false

-- you might want to add or remove applications here
local parent_filter_list = beautiful.parent_filter_list
    or { "firefox", "Gimp", "Google-chrome" }
local child_filter_list = beautiful.child_filter_list
    or { }
local swallowing_filter = beautiful.swallowing_filter
    or true

-- check if element exist in table
local function is_in_table(element, table)
    local res = false
    for _, value in pairs(table) do
        if element:match(value) then
            res = true
            break
        end
    end
    return res
end

-- checks if parent's classname can be swallowed
local function check_swallow(class, list)
    if not swallowing_filter then
        return true
    else
        return not is_in_table(class, list)
    end
end

-- the function that will be connected to / disconnected from the spawn client signal
local function manage_clientspawn(c)
    -- get the last focused window to check if it is a parent window
    local parent_client = awful.client.focus.history.get(c.screen, 1)
    if not parent_client then
        return
    end

    -- io.popen is normally discouraged. Should probably be changed
    -- returns "init(1)---ancestorA(pidA)---ancestorB(pidB)...---process(pid)"
    local handle = io.popen("pstree -A -p -s " .. tostring(c.pid))
    local parent_pid = handle:read("*a")
    handle:close()

    if
        -- will search for "(parent_client.pid)" inside the parent_pid string
        ( tostring(parent_pid):find("("..tostring(parent_client.pid)..")") )
        and check_swallow(parent_client.class, parent_filter_list)
        and check_swallow(c.class, child_filter_list)
    then
        c:connect_signal("unmanage", function()
            helpers.client.turn_on(parent_client)
            helpers.client.sync(parent_client, c)
        end)

        helpers.client.sync(c, parent_client)
        helpers.client.turn_off(parent_client)
    end
end

-- without the following functions that module would be autoloaded by require("bling")
-- a toggle window swallowing hotkey is also possible that way

local function start()
    client.connect_signal("manage", manage_clientspawn)
    window_swallowing_activated = true
end

local function stop()
    client.disconnect_signal("manage", manage_clientspawn)
    window_swallowing_activated = false
end

local function toggle()
    if window_swallowing_activated then
        stop()
    else
        start()
    end
end

return {
    start = start,
    stop = stop,
    toggle = toggle,
}
