local awful = require("awful")

local helpers = require(tostring(...):match(".*bling") .. ".helpers")

local Scratchpad = {}

--- Creates a new scratchpad object based on the argument
--
-- @param info A table of possible arguments 
-- @return The new scratchpad object
function Scratchpad:new(info)
    info = info or {}
    setmetatable(info, self)
    self.__index = self
    return info
end

--- Find all clients that satisfy the the rule
--
-- @return A list of all clients that satisfy the rule
function Scratchpad:find() return helpers.client.find(self.rule) end

--- Applies the objects scratchpad properties to a given client
--
-- @param c A client to which to apply the properties 
function Scratchpad:apply(c)
    if not c or not c.valid then return end
    c.floating = self.floating
    c.sticky = self.sticky
    c:geometry({
        x = self.geometry.x + awful.screen.focused().geometry.x,
        y = self.geometry.y + awful.screen.focused().geometry.y,
        width = self.geometry.width,
        height = self.geometry.height
    })
    if self.autoclose then
        c:connect_signal("unfocus", function(c)
            c.sticky = false -- client won't turn off if sticky
            helpers.client.turn_off(c)
        end)
    end
end

--- Turns the scratchpad on
function Scratchpad:turn_on()
    local matches = self:find()
    if matches[1] then
        -- if a client was found, turn it on
        c = matches[1]
        if self.reapply then self:apply(c) end
        -- c.sticky was set to false in turn_off so it has to be reapplied anyway
        c.sticky = self.sticky
        helpers.client.turn_on(c)
        return
    else
        -- if no client was found, spawn one, find the corresponding window,
        -- apply the properties only once (until the next closing)
        local pid = awful.spawn.with_shell(self.command)
        local function inital_apply(c)
            if helpers.client.is_child_of(c, pid) then self:apply(c) end
            client.disconnect_signal("manage", inital_apply)
        end
        client.connect_signal("manage", inital_apply)
        return
    end
end

--- Turns the scratchpad off
function Scratchpad:turn_off()
    local matches = self:find()
    local c = matches[1]
    if c then
        c.sticky = false
        helpers.client.turn_off(c)
    end
end

--- Turns the scratchpad off if it is focused otherwise it raises the scratchpad
function Scratchpad:toggle()
    local is_turn_off = false
    if self.dont_focus_before_close then
        local matches = self:find()
        if matches[1] and matches[1].first_tag then
            is_turn_off = matches[1].first_tag.selected
        end
    else
        is_turn_off = client.focus and
                          awful.rules.match(client.focus, self.rule)
    end

    if is_turn_off then
        self:turn_off()
    else
        self:turn_on()
    end
end

return Scratchpad
