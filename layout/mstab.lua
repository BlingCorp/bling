local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local gcolor = require("gears.color")
local beautiful = require("beautiful")

local mylayout = {}

mylayout.name = "mstab"

local tabbar_padding = beautiful.mstab_bar_padding or "default"
local tabbar_height = beautiful.mstab_bar_height or 40
local border_radius = beautiful.mstab_border_radius or beautiful.border_radius or 0
local tabbar_font = beautiful.mstab_font or beautiful.font or "Monospace 8"
local bg_focus = beautiful.mstab_bg_focus or beautiful.bg_focus or "#ff0000"
local bg_normal = beautiful.mstab_bg_normal or beautiful.bg_normal or "#000000"
local fg_focus = beautiful.mstab_fg_focus or beautiful.fg_focus or "#000000"
local fg_normal = beautiful.mstab_fg_normal or beautiful.fg_normal or "#ffffff"

local tabbar_orientation = "top"
if beautiful.mstab_tabbar_orientation == "bottom" then 
    tabbar_orientation = "bottom"
end 

-- The top_idx is the idx of the slave clients (excluding all master clients) 
-- that should be on top of all other slave clients ("the focused slave")
-- by creating a variable outside of the arrange function, this layout can "remember" that client
-- by creating it as a new property of every tag, this layout can be active on different tags and 
-- still have different "focused slave clients"
for idx,tag in ipairs(root.tags()) do 
    tag.top_idx = 1
end 

-- Haven't found a signal that is emitted when a new tag is added. That should work though
-- since you can't use a layout on a tag that you haven't selected previously
tag.connect_signal("property::selected", function(t)
    if not t.top_idx then
        t.top_idx = 1
    end
end)


function update_tabbar(clients, t, top_idx, area, master_area_width, slave_area_width)

    local s = t.screen

    -- create the list of clients for the tabbar
    local clientlist = wibox.layout.flex.horizontal()
    for idx,c in ipairs(clients) do
        local client_title = c.name or c.class or ""
        local client_text = wibox.widget.textbox()
        client_text.font = tabbar_font
        client_text.align = "center"
        client_text.valign = "center"
        client_text.markup = "<span foreground='" .. fg_normal .. "'>" .. client_title .. "</span>"
        local client_bg = bg_normal
        if idx == top_idx then
            client_bg = bg_focus 
            client_text.markup = "<span foreground='" .. fg_focus .. "'>" .. client_title .. "</span>"
        end
        local client_box = wibox.widget {
            client_text,
            bg = client_bg,
            widget = wibox.container.background()
        }
        -- focus with right click, kill with mid click, minimize with left click
        local buttons = gears.table.join(awful.button({}, 1, function() c:raise() client.focus = c end),
                                        awful.button({}, 2, function() c:kill() end),
                                        awful.button({}, 3, function() c.minimized = true end))
        client_box:buttons(buttons)
        clientlist:add(client_box)
    end

    -- if no tabbar exists, create one
    if not s.tabbar_exists then
		s.tabbar = wibox {
            shape = function(cr, width, height) gears.shape.rounded_rect(cr, width, height, border_radius) end,
		    bg = bg_normal,
		    visible = true
		}
        s.tabbar_exists = true
        
        -- Change visibility of the tab bar when layout, selected tag or number of clients changes
        local function adjust_visiblity(t)
            s.tabbar.visible = (#t:clients() - t.master_count > 1) and (t.layout.name == "mstab")
        end

        tag.connect_signal("property::selected", function(t) adjust_visiblity(t) end)
        tag.connect_signal("property::layout", function(t, layout) adjust_visiblity(t) end)
        tag.connect_signal("tagged", function(t, c) adjust_visiblity(t) end)
        tag.connect_signal("untagged", function(t, c) adjust_visiblity(t) end)
    end

    -- update the tabbar size and position (to support gap size change on the fly)
    s.tabbar.x = area.x + master_area_width + t.gap
    s.tabbar.y = area.y + t.gap
    s.tabbar.width  = slave_area_width -  2*t.gap
    s.tabbar.height = tabbar_height

    if tabbar_orientation == "bottom" then 
        s.tabbar.y = area.y + area.height - tabbar_height - t.gap
    end 

    -- update clientlist 
    s.tabbar:setup {
         layout = wibox.layout.flex.horizontal,
         clientlist,
    }

end

function mylayout.arrange(p)
    local area = p.workarea
    local t = p.tag or screen[p.screen].selected_tag
    local s = t.screen
    local mwfact = t.master_width_factor
    local nmaster = math.min(t.master_count, #p.clients)
    local nslaves = #p.clients - nmaster

    local master_area_width = area.width * mwfact
    local slave_area_width = area.width - master_area_width

    -- "default" means that it uses standard useless gap size
    if tabbar_padding == "default" then 
        tabbar_padding = 2*t.gap
    end

    -- Special case: No masters -> full screen slave width
    if nmaster == 0 then
        master_area_width = 1
        slave_area_width = area.width
    end

    -- Special case: One or zero slaves -> no tabbar (essentially tile right)
    if nslaves <= 1 then
        -- since update_tabbar isnt called that way we have to hide it manually
        if s.tabbar_exists then 
            s.tabbar.visible = false
        end 
        -- otherwise just do tile right 
        awful.layout.suit.tile.right.arrange(p)
        return 
    end 

    -- Iterate through masters
    for idx=1,nmaster do
         local c = p.clients[idx]
         local g = {
            x = area.x,
            y = area.y+(idx-1)*(area.height/nmaster),
            width = master_area_width,
            height = area.height/nmaster,
         }
         p.geometries[c] = g
    end

    -- TODO: The way that the slave clients are arranged is currently very hacky and unclean
    -- because of the requirement that the shadows shouldn't just add up when more slaves are added
    -- Currently clients are just shrunken down and placed "under" the "focused slave client"
    -- Ideal would be hide the same way as that small scratchpad script:
    -- https://github.com/notnew/awesome-scratch/blob/master/scratch.lua
    
    -- Iterate through slaves
    -- (also creates a list of all slave clients for update_tabbar)
    local slave_clients = {}
    for idx=1,nslaves do
         local c = p.clients[idx+nmaster]
         slave_clients[#slave_clients+1] = c
         if c == client.focus then
             t.top_idx = #slave_clients 
         end
         local g = {x=1, y=1, width=1, height=1}
         local g = {
            x = area.x + master_area_width + slave_area_width/4,
            y = area.y + tabbar_height + area.height/4,
            width = slave_area_width/2,
            height = area.height/4 - tabbar_height
         }
         if idx == t.top_idx then 
             g.width = slave_area_width
             g.height = area.height - tabbar_height - tabbar_padding
             g.x = area.x + master_area_width
             g.y = area.y
             if tabbar_orientation == "top" then 
                 g.y = g.y + tabbar_height + tabbar_padding
             else
                 g.y = g.y
             end 
         end 
         p.geometries[c] = g
    end

    update_tabbar(slave_clients, t, t.top_idx, area, master_area_width, slave_area_width)
end

local icon_raw = gears.filesystem.get_configuration_dir() .. "/bling/icons/layouts/mstab.png"

local function get_icon()
    if icon_raw ~= nil then
        return gcolor.recolor_image(icon_raw, beautiful.fg_normal)
    else
        return nil
    end
end

return {
    layout = mylayout,
    icon_raw = icon_raw,
    get_icon = get_icon,
}
