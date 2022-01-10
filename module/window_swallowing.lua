--[[
    # Swallow rules
    1. ignore_swallow -> parent refuses to be swallowed.
    2. swallow_parent -> whether a client can swallow parents.

    In my config I have:

    awful.rules.rules = {
        -- All clients
        {
            rule = {},
            properties = { swallow_parent = true }
        }
        -- Ignore swallow
        {
            rule_any = {
                class = {
                    'firefox',
                    'qutebrowser',
                }
            }
            properties = { ignore_swallow = true },
        }
        -- Don't swallow
        {
            rule_any = {
                type = {
                    'dock',
                    'splash',
                    'dialog',
                    'menu',
                    'toolbar',
                    'dropdown_menu',
                    'notification'
                },
            },
            properties = { swallow_parent = false },
        },
    }
--]]

local awful = require("awful")
local helpers = require(tostring(...):match(".*bling") .. ".helpers")
local window_swallowing_activated = false

-- async function to get the parent's pid
-- recieves a child process pid and a callback function
-- parent_pid in format "init(1)---ancestorA(pidA)---ancestorB(pidB)...---process(pid)"
function get_parent_pid(child_ppid, callback)
    local ppid_cmd = string.format("pstree -A -p -s %s", child_ppid)

    awful.spawn.easy_async(ppid_cmd, function(stdout, stderr)
        -- primitive error checking
        if stderr and stderr ~= "" then
            callback(stderr)
            return
        end
        local ppid = stdout
        callback(nil, ppid)
    end)
end


-- the function that will be connected to / disconnected from the spawn client signal
local function manage_clientspawn(c)
    -- get the last focused window to check if it is a parent window
    local parent_client = awful.client.focus.history.get(c.screen, 1)

    if not parent_client then return end

    if parent_client.ignore_swallow then return end
    if not c.swallow_parent then return end

    get_parent_pid(c.pid, function(err, ppid)
        if err then return end

        local parent_pid = ppid

        local is_parent = (tostring(parent_pid):find("("..tostring(parent_client.pid)..")"))

        if is_parent then
            c:connect_signal("unmanage", function()
                if parent_client then
                    helpers.client.turn_on(parent_client)
                    helpers.client.sync(parent_client, c)
                end
            end)

            helpers.client.sync(c, parent_client)
            helpers.client.turn_off(parent_client)
        end
    end)
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
