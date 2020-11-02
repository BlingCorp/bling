local awful = require("awful")

local helpers = {}

-- Turn off passed client (remove current tag from window's tags)
helpers.turn_off = function(c)
    local current_tag = awful.tag.selected(c.screen)
    local ctags = {}
    for k,tag in pairs(c:tags()) do
        if tag ~= current_tag then table.insert(ctags, tag) end
    end
    c:tags(ctags)
end

-- Turn on passed client
helpers.turn_on = function(c)
    local current_tag = awful.tag.selected(c.screen)
    ctags = {current_tag}
    for k,tag in pairs(c:tags()) do
        if tag ~= current_tag then table.insert(ctags, tag) end
    end
    c:tags(ctags)
    c:raise()
    client.focus = c
end

return helpers
