local awful = require("awful")

local _client = {}

--- Turn off passed client
-- Remove current tag from window's tags
--
-- @param c a client
function _client.turn_off(c)
    local current_tag = awful.tag.selected(c.screen)
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
    local current_tag = awful.tag.selected(c.screen)
    ctags = {current_tag}
    for k, tag in pairs(c:tags()) do
        if tag ~= current_tag then table.insert(ctags, tag) end
    end
    c:tags(ctags)
    c:raise()
    client.focus = c
end



return _client
