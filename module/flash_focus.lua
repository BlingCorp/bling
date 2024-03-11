local gears = require("gears")
local beautiful = require("beautiful")

local op = beautiful.flash_focus_start_opacity or 0.6
local stp = beautiful.flash_focus_step or 0.02
local transparency_rules = beautiful.flash_focus_transparency_rules or {}

local function search_rules(c)
    local found = false
    local num = 0
    for _, v in pairs(transparency_rules) do
        if string.match(v, c.class) or string.match(v, c.name) or string.match(v, c.type) then
            found = true
            num = v:match("%d+")
            break
        end
    end
    return found, num
end


local flashfocus = function(c)
    if c and #c.screen.clients > 1 then
        local found, num = search_rules(c)
        c.opacity = op
        local q = op
        local g = gears.timer({
            timeout = stp,
            call_now = false,
            autostart = true,
        })

        g:connect_signal("timeout", function()
            if not c.valid then
                return
            end
            if found then
                if q >= (tonumber(num)/100) then
                    c.opacity = (tonumber(num)/100)
                    g:stop()
                else
                    c.opacity = q
                    q = q + stp
                end
            else
                if q >= 1 then
                    c.opacity = 1
                    g:stop()
                else
                    c.opacity = q
                    q = q + stp
                end
            end
        end)
    end
end

local enable = function()
    client.connect_signal("focus", flashfocus)
end
local disable = function()
    client.disconnect_signal("focus", flashfocus)
end

return { enable = enable, disable = disable, flashfocus = flashfocus }