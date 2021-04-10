local awful = require("awful")
local gears = require("gears")

local _client = {}

--- Turn off passed client
-- Remove current tag from window's tags
--
-- @param c A client
function _client.turn_off(c)
    local current_tag = c.screen.selected_tag
    local ctags = {}
    for k, tag in pairs(c:tags()) do
        if tag ~= current_tag then table.insert(ctags, tag) end
    end
    c:tags(ctags)
end

--- Turn on passed client (add current tag to window's tags)
--
-- @param c A client
function _client.turn_on(c)
    local current_tag = c.screen.selected_tag
    ctags = {current_tag}
    for k, tag in pairs(c:tags()) do
        if tag ~= current_tag then table.insert(ctags, tag) end
    end
    c:tags(ctags)
    c:raise()
    client.focus = c
end

--- Sync two clients
--
-- @param to_c The client to which to write all properties
-- @param from_c The client from which to read all properties
function _client.sync(to_c, from_c)
    if not from_c or not to_c then return end
    if not from_c.valid or not to_c.valid then return end
    if from_c.modal then return end
    to_c.floating = from_c.floating
    to_c.maximized = from_c.maximized
    to_c.above = from_c.above
    to_c.below = from_c.below
    to_c:geometry(from_c:geometry())
    -- TODO: Should also copy over the position in a tiling layout
end

--- Checks whether the passed client is a childprocess of a given process ID
--
-- @param c A client
-- @param pid The process ID
-- @return True if the passed client is a childprocess of the given PID otherwise false
function _client.is_child_of(c, pid)
    -- io.popen is normally discouraged. Should probably be changed 
    if not c or not c.valid then return false end
    if tostring(c.pid) == tostring(pid) then return true end
    local pid_cmd = [[pstree -T -p -a -s ]] .. tostring(c.pid) ..
                        [[ | sed '2q;d' | grep -o '[0-9]*$' | tr -d '\n']]
    local handle = io.popen(pid_cmd)
    local parent_pid = handle:read("*a")
    handle:close()
    return tostring(parent_pid) == tostring(pid) or tostring(parent_pid) ==
               tostring(c.pid)
end

--- Finds all clients that satisfy the passed rule
--
-- @param rule The rule to be searched for
function _client.find(rule)
    local function matcher(c) return awful.rules.match(c, rule) end
    local clients = client.get()
    local findex = gears.table.hasitem(clients, client.focus) or 1
    local start = gears.math.cycle(#clients, findex + 1)

    local matches = {}
    for c in awful.client.iterate(matcher, start) do
        matches[#matches + 1] = c
    end

    return matches
end

return _client
