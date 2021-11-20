local awful = require("awful")
local gobject = require("gears.object")
local gtable = require("gears.table")
local gtimer = require("gears.timer")
local gfilesystem = require("gears.filesystem")
local json = require(tostring(...):match(".*bling") .. ".helpers").json
local tonumber = tonumber
local tostring = tostring
local ipairs = ipairs
local string = string
local table = table
local type = type
local capi = { awesome = awesome, root = root, screen = screen, client = client }

local persistent = { mt = {} }
local instance = nil

local function is_restart()
    capi.awesome.register_xproperty("is_restart", "boolean")
    local restart_detected = capi.awesome.get_xproperty("is_restart") ~= nil
    capi.awesome.set_xproperty("is_restart", true)

    return restart_detected
end

function persistent:save()
    self:save_tags()
    self:save_clients()

    local cache = gfilesystem.get_xdg_cache_home()
    if not gfilesystem.dir_readable(cache .. "awesome") then
        gfilesystem.make_directories(cache .. "awesome")
    end

    local json_settings = json.encode(self.settings, { indent = true })
    local path = cache .. "awesome/persistent.json"
    awful.spawn.with_shell("echo '" .. json_settings .. "'" .. " > " .. path)
end

function persistent:save_tags()
    self.settings.tags = {}

    for _, tag in ipairs(capi.root.tags()) do
        self.settings.tags[tag.index] = {}
        self.settings.tags[tag.index].name = tag.name
        self.settings.tags[tag.index].selected = tag.selected
        self.settings.tags[tag.index].activated = tag.activated
        self.settings.tags[tag.index].screen = tag.screen.index
        self.settings.tags[tag.index].master_width_factor = tag.master_width_factor
        self.settings.tags[tag.index].layout = awful.layout.get_tag_layout_index(tag)
        self.settings.tags[tag.index].volatile = tag.volatile or false
        self.settings.tags[tag.index].gap = tag.gap
        self.settings.tags[tag.index].gap_single_client = tag.gap_single_client
        self.settings.tags[tag.index].master_fill_policy = tag.master_fill_policy
        self.settings.tags[tag.index].master_count = tag.master_count
        self.settings.tags[tag.index].column_count = tag.column_count
    end
end

function persistent:save_clients()
    self.settings.clients = {}

    local properties =
    {
        "hidden", "minimized", "above", "ontop", "below", "fullscreen",
        "maximized", "maximized_horizontal", "maximized_vertical", "sticky",
        "floating", "x", "y", "width", "height"
    }

    for _, client in ipairs(capi.client.get()) do
        local pid = tostring(client.pid)
        self.settings.clients[pid] = {}

        -- Has to be blocking!
        local handle = io.popen(string.format("ps -p %d -o args=", client.pid))
        self.settings.clients[pid].command = handle:read("*a"):gsub('^%s*(.-)%s*$', '%1')
        handle:close()

        -- Properties
        for _, property in ipairs(properties) do
            for _, property in ipairs(properties) do
                self.settings.clients[pid][property] = client[property]
            end
        end
        self.settings.clients[pid].screen = client.screen.index

        -- Tags
        self.settings.clients[pid].tags = {}
        for index, client_tag in ipairs(client:tags()) do
            self.settings.clients[pid].tags[index] = client_tag.index
        end

        -- Bling tabs
        if client.bling_tabbed and client.bling_tabbed.parent == client.window then
            self.settings.clients[pid].bling_tabbed = {}
            self.settings.clients[pid].bling_tabbed.focused_idx = client.bling_tabbed.focused_idx

            self.settings.clients[pid].bling_tabbed.clients = {}
            for index, bling_tabbed_client in ipairs(client.bling_tabbed.clients) do
                self.settings.clients[pid].bling_tabbed.clients[index] = bling_tabbed_client.window
            end
        end
    end
end

function persistent:restore(args)
    args = args or {}

    local path = gfilesystem.get_xdg_cache_home() .. "awesome/persistent.json"
    awful.spawn.easy_async_with_shell("cat " .. path, function(stdout)
        self.restored_settings = json.decode(stdout)
        self:restore_tags(args)
        self:restore_clients(args)
    end)
end

function persistent:restore_tags(args)
    args = args or {}

    local selected_tag = false
    awful.tag.viewnone()

    if args.create_tags == true then
        for _, tag in ipairs(self.restored_settings.tags) do
            awful.tag.add(tag.name, tag)
            if tag.selected == true then
                awful.tag.viewtoggle(tag)
                selected_tag = true
            end
        end
    else
        for index, tag in ipairs(capi.root.tags()) do
            tag.name = self.restored_settings.tags[index].name
            tag.activated = self.restored_settings.tags[index].activated
            tag.screen = self.restored_settings.tags[index].screen
            tag.master_width_factor = self.restored_settings.tags[index].master_width_factor
            tag.layout = awful.layout.layouts[self.restored_settings.tags[index].layout]
            tag.volatile = self.restored_settings.tags[index].volatile
            tag.gap = self.restored_settings.tags[index].gap
            tag.gap_single_client = self.restored_settings.tags[index].gap_single_client
            tag.master_fill_policy = self.restored_settings.tags[index].master_fill_policy
            tag.master_count = self.restored_settings.tags[index].master_count
            tag.column_count = self.restored_settings.tags[index].column_count

            if self.restored_settings.tags[index].selected == true then
                awful.tag.viewtoggle(tag)
                selected_tag = true
            end
        end
    end

    if selected_tag == false then
        awful.tag.viewtoggle(capi.root.tags()[1])
    end
end

function persistent:restore_clients()
    for index, client in ipairs(capi.client.get()) do
        local pid =  tostring(client.pid)

        -- Properties
        local properties =
        {
            "hidden", "minimized", "above", "ontop", "below", "fullscreen",
            "maximized", "maximized_horizontal", "maximized_vertical", "sticky",
            "floating", "x", "y", "width", "height"
        }
        for _, property in ipairs(properties) do
            client[property] = self.restored_settings.clients[pid][property]
        end
        client:move_to_screen(self.restored_settings.clients[pid].screen)

        -- Tags
        gtimer.delayed_call(function()
            local tags = {}
            for _, tag in ipairs(self.restored_settings.clients[pid].tags) do
                table.insert(tags, capi.screen[client.screen].tags[tag])
            end
            client.first_tag = tags[1]
            client:tags(tags)
        end)

        -- Bling tabbed
        local parent = client
        if self.restored_settings.clients[pid].bling_tabbed then
            for _, window in ipairs(self.restored_settings.clients[pid].bling_tabbed.clients) do
                for index, client in ipairs(capi.client.get()) do
                    if client.window == window then
                        local focused_idx = self.restored_settings.clients[pid].bling_tabbed.focused_idx
                        if not parent.bling_tabbed and not client.bling_tabbed then
                            tabbed.init(parent)
                            tabbed.add(client, parent.bling_tabbed)
                            gtimer.delayed_call(function()
                                tabbed.switch_to(parent.bling_tabbed, focused_idx)
                            end)
                        end
                        if not parent.bling_tabbed and client.bling_tabbed then
                            tabbed.add(parent, client.bling_tabbed)
                            gtimer.delayed_call(function()
                                tabbed.switch_to(client.bling_tabbed, focused_idx)
                            end)
                        end
                        if parent.bling_tabbed and not client.bling_tabbed then
                            tabbed.add(client, parent.bling_tabbed)
                            gtimer.delayed_call(function()
                                tabbed.switch_to(parent.bling_tabbed, focused_idx)
                            end)
                        end
                        client:tags({})
                    end
                end
            end
        end
    end
end

function persistent:enable(args)
    capi.awesome.connect_signal("exit", function(reason_restart)
        if reason_restart == true then
            self:save()
        end
    end)

    capi.awesome.connect_signal("startup", function(reason_restart)
        if is_restart() == true then
            self:restore(args)
        end
    end)
end

local function new()
    local ret = gobject{}
    gtable.crush(ret, persistent, true)
    ret.settings = {}

    return ret
end

if not instance then
    instance = new()
end
