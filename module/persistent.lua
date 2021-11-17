local awful = require("awful")
local gobject = require("gears.object")
local gtable = require("gears.table")
local gtimer = require("gears.timer")
local tonumber = tonumber
local tostring = tostring
local ipairs = ipairs
local table = table
local type = type
local capi = { awesome = awesome, root = root, screen = screen, client = client }

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
    return client:get_xproperty(xprop)
end

local function client_set_xproperty(client, name, type, value)
    local xprop = "bling.client." .. name
    capi.awesome.register_xproperty(xprop, type)
    client:set_xproperty(xprop, value)
end

function persistent:save()
    self:save_tags()
    self:save_clients()
end

function persistent:save_tags()
    set_xproperty("tag_index", "number", awful.screen.focused().selected_tag.index)

    for _, tag in ipairs(capi.root.tags()) do
        local name_property = "tag_" .. tag.index .. "_name"
        set_xproperty(name_property, "string", tag.name)

        local activated_property = "tag_" .. tag.index .. "_activated"
        set_xproperty(activated_property, "boolean", tag.activated)

        local selected_property = "tag_" .. tag.index .. "_selected"
        set_xproperty(selected_property, "boolean", tag.selected)

        local master_width_factor_property = "tag_" .. tag.index .. "_master_width_factor"
        set_xproperty(master_width_factor_property, "string", tostring(tag.master_width_factor))

        local layout_property = "tag_" .. tag.index .. "_layout"
        set_xproperty(layout_property, "number", awful.layout.get_tag_layout_index(tag))

        local volatile_property = "tag_" .. tag.index .. "_volatile"
        set_xproperty(volatile_property, "boolean", tag.volatile)

        local gap_property = "tag_" .. tag.index .. "_gap"
        set_xproperty(gap_property, "string", tostring(tag.gap))

        local gap_single_client_property = "tag_" .. tag.index .. "_gap_single_client"
        set_xproperty(gap_single_client_property, "boolean", tag.gap_single_client)

        local master_fill_policy_property = "tag_" .. tag.index .. "_master_fill_policy"
        set_xproperty(master_fill_policy_property, "string", tag.master_fill_policy)

        local master_count_property = "tag_" .. tag.index .. "_master_count"
        set_xproperty(master_count_property, "number", tag.master_count)

        local column_count_property = "tag_" .. tag.index .. "_column_count"
        set_xproperty(column_count_property, "number", tag.column_count)
    end
end

function persistent:save_clients()
    local properties = { "hidden", "minimized", "above", "ontop", "below", "fullscreen",
                        "maximized", "maximized_horizontal", "maximized_vertical", "sticky",
                        "floating", "x", "y", "width", "height"}

    for index, client in ipairs(capi.client.get()) do
        for _, property in ipairs(properties) do
            client_set_xproperty(client, property, type(client[property]), client[property])
        end

        client_set_xproperty(client, "screen", "number", client.screen.index)
        client_set_xproperty(client, "tags_count", "number", #client:tags())
        for index, client_tag in ipairs(client:tags()) do
            client_set_xproperty(client, "tag_" .. index, "number", client_tag.index)
        end

        if client.bling_tabbed and client.bling_tabbed.parent == client.window then
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

function persistent:restore()
    self:restore_tags()
    self:restore_clients()
end

function persistent:restore_tags()
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
end

function persistent:restore_clients()
    for index, client in ipairs(capi.client.get()) do
        local properties = { "hidden", "minimized", "above", "ontop", "below", "fullscreen",
                            "maximized", "maximized_horizontal", "maximized_vertical", "sticky",
                            "floating", "x", "y", "width", "height"}

        for _, property in ipairs(properties) do
            client[property] = client_get_xproperty(client, property, type(client[property]))
        end
        client:move_to_screen(client_get_xproperty(client, "screen", "number"))

        local parent = client
        local bling_tabbed_clients_amount = client_get_xproperty(parent, "bling_tabbed_clients_amount", "number") or 0
        for i = 1, bling_tabbed_clients_amount, 1 do
            local child_window = tonumber(client_get_xproperty(parent, "bling_tabbed_client_" .. i, "string"))
            for index, child in ipairs(capi.client.get()) do
                if child.window == child_window then
                    local tab_index = client_get_xproperty(client, "bling_tabbed_focused_idx", "number")
                    if not parent.bling_tabbed and not child.bling_tabbed then
                        tabbed.init(parent)
                        tabbed.add(child, parent.bling_tabbed)
                        gtimer.delayed_call(function()
                            tabbed.switch_to(parent.bling_tabbed, tab_index)
                        end)
                    end
                    if not parent.bling_tabbed and child.bling_tabbed then
                        tabbed.add(parent, child.bling_tabbed)
                        gtimer.delayed_call(function()
                            tabbed.switch_to(child.bling_tabbed, tab_index)
                        end)
                    end
                    if parent.bling_tabbed and not child.bling_tabbed then
                        tabbed.add(child, parent.bling_tabbed)
                        gtimer.delayed_call(function()
                            tabbed.switch_to(parent.bling_tabbed, tab_index)
                        end)
                    end
                    child:tags({})
                end
            end
        end

        gtimer.delayed_call(function()
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

function persistent:enable()
    capi.awesome.connect_signal("exit", function(reason_restart)
        if reason_restart == true then
            self:save()
        end
    end)

    gtimer.delayed_call(function()
        self:restore()
    end)
end

local function new()
    if instance then
        return instance
    end

    instance = gobject{}
    gtable.crush(instance, persistent, true)

    return instance
end

return setmetatable(persistent, persistent.mt)