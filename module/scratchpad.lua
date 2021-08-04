local awful = require("awful")
local gears = require("gears")

local helpers = require(tostring(...):match(".*bling") .. ".helpers")

local Scratchpad = { mt = {} }

--- Creates a new scratchpad object based on the argument
--
-- @param args A table of possible arguments
-- @return The new scratchpad object
function Scratchpad:new(args)
    args = args or {}
    args.awestore = args.awestore or {}
    args.in_anim = false
    local ret = gears.object {}
    gears.table.crush(ret, Scratchpad)
    gears.table.crush(ret, args)
    return ret
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
        c:connect_signal("unfocus", function(c1)
            c1.sticky = false -- client won't turn off if sticky
            helpers.client.turn_off(c1)
        end)
    end
end

--- Turns the scratchpad on
function Scratchpad:turn_on()
    local matches = self:find()
    local c = matches[1]
    if c and not self.in_anim and c.first_tag and c.first_tag.selected then
        c:raise()
        client.focus = c
        return
    end
    if c and not self.in_anim then
        -- if a client was found, turn it on
        if self.reapply then self:apply(c) end
        -- c.sticky was set to false in turn_off so it has to be reapplied anyway
        c.sticky = self.sticky
        local new_y = c.y
        local new_x = c.x

        -- Get the tweens
        local anim_x = self.awestore.x
        local anim_y = self.awestore.y

        -- Subscribe
        if anim_x then
            anim_x:subscribe(function(x)
                if c and c.valid then c.x = x end
                self.in_anim = true
            end)
        end
        if anim_y then
            anim_y:subscribe(function(y)
                if c and c.valid then c.y = y end
                self.in_anim = true
            end)
        end

        helpers.client.turn_on(c)
        self:emit_signal("turn_on", c)

        -- Unsubscribe
        if anim_x then
            anim_x:set(new_x)
            local unsub_x
            unsub_x = anim_x.ended:subscribe(
                          function()
                    self.in_anim = false
                    unsub_x()
                end)
        end
        if anim_y then
            anim_y:set(new_y)
            local unsub_y
            unsub_y = anim_y.ended:subscribe(
                          function()
                    self.in_anim = false
                    unsub_y()
                end)
        end
        return
    end
    if not c then
        -- if no client was found, spawn one, find the corresponding window,
        --  apply the properties only once (until the next closing)
        local pid = awful.spawn.with_shell(self.command)
        self:emit_signal("spawn")
        local function inital_apply(c1)
            if helpers.client.is_child_of(c1, pid) then
                self:apply(c1)
                self:emit_signal("inital_apply", c1)
            client.disconnect_signal("manage", inital_apply)
            end
        end
        client.connect_signal("manage", inital_apply)
        return
    end
end

--- Turns the scratchpad off
function Scratchpad:turn_off()
    local matches = self:find()
    local c = matches[1]
    if c and not self.in_anim then
        c.sticky = false

        -- Get the tweens
        local anim_x = self.awestore.x
        local anim_y = self.awestore.y

        -- Subscribe
        if anim_x then
            anim_x:subscribe(function(x)
                if c and c.valid then c.x = x end
                self.in_anim = true
            end)
        end
        if anim_y then
            anim_y:subscribe(function(y)
                if c and c.valid then c.y = y end
                self.in_anim = true
            end)
        end

        -- Unsubscribe
        if anim_x then
            anim_x:set(anim_x:initial())
            local unsub
            unsub = anim_x.ended:subscribe(
                        function()
                    self.in_anim = false
                    helpers.client.turn_off(c)
                    self:emit_signal("turn_off", c)
                    unsub()
                end)
        end
        if anim_y then
            anim_y:set(anim_y:initial())

            local unsub
            unsub = anim_y.ended:subscribe(
                        function()
                    self.in_anim = false
                    helpers.client.turn_off(c)
                    self:emit_signal("turn_off", c)
                    unsub()
                end)
        end

        if not anim_x and not anim_y then
            helpers.client.turn_off(c)
            self:emit_signal("turn_off", c)
        end
    end
end

--- Turns the scratchpad off if it is focused otherwise it raises the scratchpad
function Scratchpad:toggle()
    local is_turn_off = false
    local matches = self:find()
    if self.dont_focus_before_close then
        if matches[1] then
            local current_tag = matches[1].screen.selected_tag
            for k, tag in pairs(matches[1]:tags()) do
                if tag == current_tag then
                    is_turn_off = true
                    break
                else
                    is_turn_off = false
                end
            end
        end
    else
        is_turn_off = client.focus and
                          awful.rules.match(client.focus, self.rule)
    end

    if is_turn_off then
        if self.disable_floating_on_close and matches[1].floating == true then
            matches[1].floating = false
        end
        self:turn_off()
    else
        self:turn_on()
    end
end

--- Make the module callable without putting a `:new` at the end of it
--
-- @param args A table of possible arguments
-- @return The new scratchpad object
function Scratchpad.mt:__call(...)
    return Scratchpad:new(...)
end

return setmetatable(Scratchpad, Scratchpad.mt)

