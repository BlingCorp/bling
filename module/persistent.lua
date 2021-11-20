local awful = require("awful")
local gobject = require("gears.object")
local gtable = require("gears.table")
local gtimer = require("gears.timer")
local gfilesystem = require("gears.filesystem")
local json = require(tostring(...):match(".*bling") .. ".helpers").json
local tostring = tostring
local string = string
local ipairs = ipairs
local pairs = pairs
local table = table
local capi = { awesome = awesome, root = root, screen = screen, client = client }

local persistent = { }
local instance = nil

local function is_restart()
    capi.awesome.register_xproperty("is_restart", "boolean")
    local restart_detected = capi.awesome.get_xproperty("is_restart") ~= nil
    capi.awesome.set_xproperty("is_restart", true)

    return restart_detected
end

local function reapply_clients(self)
    for index, client in ipairs(capi.client.get()) do
        local pid =  tostring(client.pid)
        if self.restored_settings.clients[pid] == nil then
            return
        end

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

local function save_tags(self)
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

local function save_clients(self)
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

local function restore_tags(self, args)
    args.create_tags = args.create_tags ~= nil and args.create_tags or false

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
        -- awful.tag.viewtoggle(capi.root.tags()[1])
    end
end

local function restore_clients(self, args)
    args.create_clients = args.create_clients ~= nil and args.create_clients or false

    if args.create_clients == true then
        for pid, client in pairs(self.restored_settings.clients) do
            local new_pid = awful.spawn(client.command, false)
            self.restored_settings.clients[tostring(new_pid)] = self.restored_settings.clients[pid]
            self.restored_settings.clients[pid] = nil
        end

        gtimer {
            timeout = 3,
            call_now = false,
            autostart = true,
            single_shot = true,
            callback = function()
                reapply_clients(self)
            end
        }
    else
        reapply_clients(self)
    end
end

function persistent:save(args)
    args = args or {}

    args.save_tags = args.save_tags == nil and true or args.save_tags
    args.save_clients = args.save_clients == nil and true or args.save_clients

    if args.save_tags == true then
        save_tags(self)
    end
    if args.save_clients ==  true then
        save_clients(self)
    end

    local cache = gfilesystem.get_xdg_cache_home()
    if not gfilesystem.dir_readable(cache .. "awesome") then
        gfilesystem.make_directories(cache .. "awesome")
    end

    local json_settings = json.encode(self.settings, { indent = true })
    local path = cache .. "awesome/persistent.json"
    awful.spawn.with_shell("echo '" .. json_settings .. "'" .. " > " .. path)
end

function persistent:restore(args)
    args = args or {}

    args.restore_tags = args.restore_tags == nil and true or args.restore_tags
    args.restore_clients = args.restore_clients == nil and true or args.restore_clients

    local path = gfilesystem.get_xdg_cache_home() .. "awesome/persistent.json"
    awful.spawn.easy_async_with_shell("cat " .. path, function(stdout)
        self.restored_settings = json.decode(stdout)
        if args.restore_tags == true then
            restore_tags(self, args)
        end
        if args.restore_clients ==  true then
            restore_clients(self, args)
        end
    end)
end

function persistent:enable(args)
    args = args or {}

    capi.awesome.connect_signal("exit", function()
        self:save(args)
    end)

    capi.awesome.connect_signal("startup", function()
        if is_restart() == false then
            args.create_clients = args.create_clients == nil and true or args.create_clients
        end

        self:restore(args)
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
