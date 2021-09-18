local awful = require("awful")
local gears = require("gears")

local capi =
{
    awesome = awesome,
    root = root,
    screen = screen,
    client = client
}
local ipairs = ipairs
local table = table
local tonumber = tonumber
local tostring = tostring

local persistent = { mt = {} }
local instance = nil

local function get_xproperty(name, type)
    capi.awesome.register_xproperty(name, type)
    return capi.awesome.get_xproperty(name)
end

local function set_xproperty(name, type, value)
    capi.awesome.register_xproperty(name, type)
    capi.awesome.set_xproperty(name, value)
end

local function client_get_xproperty(client, name, type)
    local xprop = "bling.client." .. name
    capi.awesome.register_xproperty(xprop, type)
    -- print(xprop .. "  " .. tostring(client:get_xproperty(xprop)))
    return client:get_xproperty(xprop)
end

local function client_set_xproperty(client, name, type, value)
    local xprop = "bling.client." .. name
    capi.awesome.register_xproperty(xprop, type)
    client:set_xproperty(xprop, value)
end

local function save()
    set_xproperty("tag_index", "number", awful.screen.focused().selected_tag.index)

    for index, entry in ipairs(capi.root.tags()) do
        local master_width_property = "tag_" .. entry.index .. "_master_width_factor"
        set_xproperty(master_width_property, "string", tostring(entry.master_width_factor))

        local layout_property = "tag_" .. entry.index .. "_layout"
        set_xproperty(layout_property, "number", awful.layout.get_tag_layout_index(entry))
    end

    for index, client in ipairs(capi.client.get()) do
        client_set_xproperty(client, "screen", "number", client.screen.index)
        client_set_xproperty(client, "hidden", "boolean", client.hidden)
        client_set_xproperty(client, "minimized", "boolean", client.minimized)
        client_set_xproperty(client, "above", "boolean", client.above)
        client_set_xproperty(client, "ontop", "boolean", client.ontop)
        client_set_xproperty(client, "below", "boolean", client.below)
        client_set_xproperty(client, "fullscreen", "boolean", client.fullscreen)
        client_set_xproperty(client, "maximized", "boolean", client.maximized)
        client_set_xproperty(client, "maximized_horizontal", "boolean", client.maximized_horizontal)
        client_set_xproperty(client, "maximized_vertical", "boolean", client.maximized_vertical)
        client_set_xproperty(client, "sticky", "boolean", client.sticky)
        client_set_xproperty(client, "floating", "boolean", client.floating)
        client_set_xproperty(client, "x", "string", tostring(client.x))
        client_set_xproperty(client, "y", "string", tostring(client.y))
        client_set_xproperty(client, "width", "string", tostring(client.width))
        client_set_xproperty(client, "height", "string", tostring(client.height))

        client_set_xproperty(client, "tags_count", "number", #client:tags())
        for index, client_tag in ipairs(client:tags()) do
            client_set_xproperty(client, "tag_" .. index, "number", client_tag.index)
        end

        if client.bling_tabbed then
            client_set_xproperty(client, "bling_tabbed_clients_amount", "number", #client.bling_tabbed.clients)
            client_set_xproperty(client, "bling_tabbed_focused_idx", "number", tostring(client.bling_tabbed.focused_idx))
            for index, bling_tabbed_client in ipairs(client.bling_tabbed.clients) do
                client_set_xproperty(client, "bling_tabbed_client_" .. index, "string", tostring(bling_tabbed_client.window))
            end
        else
            client_set_xproperty(client, "bling_tabbed_clients_amount", "number", 0)
        end
    end
end

local function restore()
    local tag = awful.screen.focused().tags[get_xproperty("tag_index", "number")]
    if tag then
        tag:view_only()
    end

    for index, entry in ipairs(capi.root.tags()) do
        local master_width_factor = tonumber(get_xproperty("tag_" .. entry.index .. "_master_width_factor", "string"))
        if master_width_factor ~= nil then
            entry.master_width_factor = master_width_factor
        end
        local layout = awful.layout.layouts[get_xproperty("tag_" .. entry.index .. "_layout", "number")]
        if layout ~= nil then
            entry.layout = layout
        end
    end

    for index, client in ipairs(capi.client.get()) do
        client.screen = client_get_xproperty(client, "screen", "number")
        client.hidden = client_get_xproperty(client, "hidden", "boolean")
        client.minimized = client_get_xproperty(client, "minimized", "boolean")
        client.above = client_get_xproperty(client, "above", "boolean")
        client.ontop = client_get_xproperty(client, "ontop", "boolean")
        client.below = client_get_xproperty(client, "below", "boolean")
        client.fullscreen = client_get_xproperty(client, "fullscreen", "boolean")
        client.maximized = client_get_xproperty(client, "maximized", "boolean")
        client.maximized_horizontal = client_get_xproperty(client, "maximized_horizontal", "boolean")
        client.maximized_vertical = client_get_xproperty(client, "maximized_vertical", "boolean")
        client.sticky = client_get_xproperty(client, "sticky", "boolean")
        client.floating = client_get_xproperty(client, "floating", "boolean")
        client.x = tonumber(client_get_xproperty(client, "x", "string"))
        client.y = tonumber(client_get_xproperty(client, "y", "string"))
        client.width = tonumber(client_get_xproperty(client, "width", "string"))
        client.height = tonumber(client_get_xproperty(client, "height", "string"))

        local bling_tabbed_clients_amount = client_get_xproperty(client, "bling_tabbed_clients_amount", "number") or 0
        for i = 1, bling_tabbed_clients_amount, 1 do
            local client_window = tonumber(client_get_xproperty(client, "bling_tabbed_client_" .. i, "string"))
            local parent = client
            for index, entry in ipairs(capi.client.get()) do
                local tab_index = client_get_xproperty(client, "bling_tabbed_focused_idx", "number")
                if entry.window == client_window then
                    if not parent.bling_tabbed and not entry.bling_tabbed then
                        tabbed.init(parent)
                        tabbed.add(entry, parent.bling_tabbed)
                        gears.timer.delayed_call(function() tabbed.switch_to(parent.bling_tabbed, tab_index) end)
                    end
                    if not parent.bling_tabbed and entry.bling_tabbed then
                        tabbed.add(parent, entry.bling_tabbed)
                        gears.timer.delayed_call(function() tabbed.switch_to(entry.bling_tabbed, tab_index) end)
                    end
                    if parent.bling_tabbed and not entry.bling_tabbed then
                        tabbed.add(entry, parent.bling_tabbed)
                        gears.timer.delayed_call(function() tabbed.switch_to(parent.bling_tabbed, tab_index) end)
                    end
                   entry :tags({})
                end
            end
        end

        gears.timer.delayed_call(function()
            local tags_count = client_get_xproperty(client, "tags_count", "number") or 0
            local tags = {}
            for i = 1, tags_count, 1 do
                local tag_index = client_get_xproperty(client, "tag_" .. i, "number")
                table.insert(tags, capi.screen[client.screen].tags[tag_index])
            end

            client.first_tag = tags[1]
            client:tags(tags)
        end)
    end
end

local function new(args)
    local ret = gears.object{}
    gears.table.crush(ret, persistent, true)

    capi.awesome.connect_signal("exit", function(reason_restart)
        if reason_restart == true then
            save()
        end
    end)

    gears.timer.delayed_call(function()
        restore()
    end)

    return ret
end

function persistent.mt:__call(...)
    if not instance then
        instance = new(...)
    end
    return instance
end

return setmetatable(persistent, persistent.mt)