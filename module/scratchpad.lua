local awful = require("awful")
local gears = require("gears")

local ruled
if awesome.version ~= "v4.3" then ruled = require("ruled") end

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
            anim_x:subscribe(function(x, time)
                if c and c.valid then c.x = x end
                self.in_anim = true
            end)
            -- Check for the following scenerio:
            -- Toggle on scratchpad at tag 1
            -- Toggle on scratchpad at tag 2
            -- The animation will instantly end
            -- as the timer pos is already at the on position
            -- from toggling on the scratchpad at tag 1
            if anim_x.pos == self.geometry.x then
                anim_x.pos = anim_x:initial()
            end
            anim_x:set(new_x)
            anim_x.ended:subscribe(function()
                self.in_anim = false
                anim_x:unsubscribe()
                anim_x:reset()
                anim_x.ended:unsubscribe()
            end)
        end
        if anim_y then
            anim_y:subscribe(function(y, time)
                if c and c.valid then c.y = y end
                self.in_anim = true
            end)
            -- Check for the following scenerio:
            -- Toggle on scratchpad at tag 1
            -- Toggle on scratchpad at tag 2
            -- The animation will instantly end
            -- as the timer pos is already at the on position
            -- from toggling on the scratchpad at tag 1
            if anim_y.pos == self.geometry.y then
                anim_y.pos = anim_y:initial()
            end
            anim_y:set(new_y)
            anim_y.ended:subscribe(function()
                self.in_anim = false
                anim_y:unsubscribe()
                anim_y:reset()
                anim_y.ended:unsubscribe()
            end)
        end

        helpers.client.turn_on(c)
        self:emit_signal("turn_on", c)

        return
    end
    if not c then
        -- if no client was found, spawn one, find the corresponding window,
        --  apply the properties only once (until the next closing)
        local pid = awful.spawn.with_shell(self.command)
        if awesome.version ~= "v4.3" then
            ruled.client.append_rule
            {
                id = "scratchpad",
                rule = self.rule,
                properties =
                {
                    -- If a scratchpad is opened it should spawn at the current tag
                    -- the same way it will behave if the client was already open
                    tag = awful.screen.focused().selected_tag,
                    switch_to_tags = false,
                    -- Hide the client until the gemoetry rules are applied
                    hidden = true,
                    minimized = true
                },
                callback = function(c)
                    -- For a reason I can't quite get the gemotery rules will fail to apply unless we use this timer
                    gears.timer{timeout = 0.15, autostart = true, single_shot = true, callback = function()
                        self:apply(c)
                        c.hidden = false
                        c.minimized = false
                        -- Some clients fail to gain focus
                        c:activate{}

                        -- Discord spawns 2 windows, so keep the rule until the 2nd window shows
                        if c.name ~= "Discord Updater" then ruled.client.remove_rule("scratchpad") end
                        -- In a case Discord is killed before the second window spawns
                        c:connect_signal("request::unmanage", function() ruled.client.remove_rule("scratchpad") end)
                    end}
                end
            }
        else
            local function inital_apply(c1)
                if helpers.client.is_child_of(c1, pid) then
                    self:apply(c1)
                    self:emit_signal("inital_apply", c1)
                client.disconnect_signal("manage", inital_apply)
                end
            end
            client.connect_signal("manage", inital_apply)
        end
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
            local init_x = c.x
            local current_tag_on_toggled_scratchpad = c.screen.selected_tag
            -- can't animate not floating windows
            c.floating = true
            -- if the app wasn't opened via a scratchpad
            -- and you toggle it off via a scratchpad
            -- the animation will look wrong since the gemotery wasn't applied
            self:apply(c)
            anim_x:subscribe(function(x, time)
                if c and c.valid then c.x = x end
                self.in_anim = true

                -- Handles changing tag mid animation
                -- Check for the following scenerio:
                -- Toggle on scratchpad at tag 1
                -- Toggle on scratchpad at tag 2
                -- Toggle off scratchpad at tag 1
                -- Switch to tag 2
                -- The client will remain on tag 1
                -- The client will be removed from tag 2
                if c.screen.selected_tag ~= current_tag_on_toggled_scratchpad then
                    self.in_anim = false
                    anim_x:abort()
                    anim_x:reset()
                    anim_x.pos = self.geometry.x
                    anim_x:unsubscribe()
                    helpers.client.turn_off(c, current_tag_on_toggled_scratchpad)
                    self:apply(c)
                    self:emit_signal("turn_off", c)
                end
            end)
            -- Check for the following scenerio:
            -- Toggle on scratchpad at tag 1
            -- Toggle on scratchpad at tag 2
            -- Toggle off scratchpad at tag 1
            -- Toggle off scratchpad at tag 2
            -- The animation will instantly end
            -- as the timer pos is already at the off position
            -- from toggling off the scratchpad at tag 1
            if anim_x.pos == anim_x:initial() then
                anim_x.pos = self.geometry.x
            end
            anim_x:set(anim_x:initial())
            anim_x.ended:subscribe(function()
                self.in_anim = false
                anim_x:unsubscribe()
                anim_x:reset()
                helpers.client.turn_off(c)
                -- When toggling off a scratchpad that's present on multiple tags
                -- depsite still being unminizmied on the other tags it will become invisible
                -- as it's position could be outside the screen
                c.x = init_x
                self:emit_signal("turn_off", c)
                anim_x.ended:unsubscribe()
            end)
        end
        if anim_y then
            local init_y = c.y
            local current_tag_on_toggled_scratchpad = c.screen.selected_tag
            -- can't animate not floating windows
            c.floating = true
            -- if the app wasn't opened via a scratchpad
            -- and you toggle it off via a scratchpad
            -- the animation will look wrong since the gemotery wasn't applied
            self:apply(c)
            anim_y:subscribe(function(y, time)
                if c and c.valid then c.y = y end
                self.in_anim = true

                -- Handles changing tag mid animation
                -- Check for the following scenerio:
                -- Toggle on scratchpad at tag 1
                -- Toggle on scratchpad at tag 2
                -- Toggle off scratchpad at tag 1
                -- Switch to tag 2
                -- The client will remain on tag 1
                -- The client will be removed from tag 2
                if c.screen.selected_tag ~= current_tag_on_toggled_scratchpad then
                    self.in_anim = false
                    anim_y:abort()
                    anim_y:reset()
                    anim_y.pos = self.geometry.y
                    anim_y:unsubscribe()
                    helpers.client.turn_off(c, current_tag_on_toggled_scratchpad)
                    self:apply(c)
                    self:emit_signal("turn_off", c)
                end
            end)
            -- Check for the following scenerio:
            -- Toggle on scratchpad at tag 1
            -- Toggle on scratchpad at tag 2
            -- Toggle off scratchpad at tag 1
            -- Toggle off scratchpad at tag 2
            -- The animation will instantly end
            -- as the timer pos is already at the off position
            -- from toggling off the scratchpad at tag 1
            if anim_y.pos == anim_y:initial() then
                anim_y.pos = self.geometry.y
            end
            anim_y:set(anim_y:initial())
            anim_y.ended:subscribe(function()
                self.in_anim = false
                anim_y:unsubscribe()
                anim_y:reset()
                helpers.client.turn_off(c)
                -- When toggling off a scratchpad that's present on multiple tags
                -- depsite still being unminizmied on the other tags it will become invisible
                -- as it's position could be outside the screen
                c.y = init_y
                self:emit_signal("turn_off", c)
                anim_y.ended:unsubscribe()
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
