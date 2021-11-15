local awful = require("awful")
local gears = require("gears")
local beautiful = require("beautiful")

local helpers = require(tostring(...):match(".*bling") .. ".helpers")

-- It might actually swallow too much, that's why there is a filter option by classname
-- without the don't-swallow-list it would also swallow for example
-- file pickers or new firefox windows spawned by an already existing one

local window_swallowing_activated = false

-- you might want to add or remove applications here
local dont_swallow_classname_list = beautiful.dont_swallow_classname_list
    or { "firefox", "Gimp", "Google-chrome" }
local cant_swallow_classname_list = beautiful.cant_swallow_classname_list
    or { "Yad" }
local activate_dont_swallow_filter = beautiful.dont_swallow_filter_activated
    or true

-- check if element exist in table
local function is_in_table(element, table)
    for _, value in pairs(table) do
        if element:match(value) then
            return true
        end
    return false
    end
end

-- checks if client classname can be swallowed
local function check_if_swallow(class)
    if not activate_dont_swallow_filter then
        return true
    else
        return not is_in_table(class, dont_swallow_classname_list)
    end
end

-- checks if client classname can swallow it's parent
local function check_can_swallow(class)
    if not activate_dont_swallow_filter then
        return true
    else
        return not is_in_table(class, cant_swallow_classname_list)
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
        and check_if_swallow(parent_client.class) and check_can_swallow(c.class)
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
