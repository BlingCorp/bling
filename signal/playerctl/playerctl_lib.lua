-- Playerctl signals
--
-- Provides:
-- metadata
--      title (string)
--      artist  (string)
--      album_path (string)
--      player_name (string)
--      album (string)
--      new (bool)
-- position
--      interval_sec (number)
--      length_sec (number)
--      player_name (string)
-- playback_status
--      playing (boolean)
--      player_name (string)
-- volume
--      volume (number)
--      player_name (string)
-- loop_status
--      loop_status (boolean)
--      player_name (string)
-- shuffle
--      shuffle (boolean)
--      player_name (string)
-- no_players
--      (No parameters)

local awful = require("awful")
local gobject = require("gears.object")
local gtable = require("gears.table")
local gtimer = require("gears.timer")
local gstring = require("gears.string")
local beautiful = require("beautiful")
local setmetatable = setmetatable
local ipairs = ipairs

local playerctl = { mt = {} }
local instance = nil

-- Settings
local ignore = {}
local priority = {}
local update_on_activity = true
local interval = 1
local debounce_delay = 0.35

-- Locals
local lgi_Playerctl = nil
local manager = nil
local metadata_timer = nil
local position_timer = nil

-- Track position callback
local last_position = -1
local last_length = -1

-- Metadata callback for title, artist, and album art
local last_player = nil
local last_title = ""
local last_artist = ""
local last_artUrl = ""

function playerctl:pause()
    if manager.players[1] then
        manager.players[1].pause(manager.players[1])
    end
end

function playerctl:play()
    if manager.players[1] then
        manager.players[1].play(manager.players[1])
    end
end

function playerctl:stop()
    if manager.players[1] then
        manager.players[1].stop(manager.players[1])
    end
end

function playerctl:play_pause()
    if manager.players[1] then
        manager.players[1].play_pause(manager.players[1])
    end
end

function playerctl:previous()
    if manager.players[1] then
        manager.players[1].previous(manager.players[1])
    end
end

function playerctl:next()
    if manager.players[1] then
        manager.players[1].next(manager.players[1])
    end
end

function playerctl:set_loop_status(loop_status)
    if manager.players[1] then
        manager.players[1].set_loop_status(manager.players[1], loop_status)
    end
end

function playerctl:set_position()
    if manager.players[1] then
        -- Disabled as it throws:
        -- (process:115888): GLib-CRITICAL **: 09:53:03.111: g_variant_new_object_path: assertion 'g_variant_is_object_path (object_path)' failed
        --manager.players[1].set_position(manager.players[1], 1000)
    end
end

function playerctl:set_shuffle(shuffle)
    if manager.players[1] then
        manager.players[1].set_shuffle(manager.players[1], shuffle)
    end
end

function playerctl:set_volume(volume)
    if manager.players[1] then
        manager.players[1].set_volume(manager.players[1], volume)
    end
end

function playerctl:get_manager()
    return manager
end

function playerctl:get_active_player()
    return manager.players[1]
end

local function emit_metadata_signal(self, title, artist, artUrl, player_name, album, new)
    title = gstring.xml_escape(title)
    artist = gstring.xml_escape(artist)
    album = gstring.xml_escape(album)

    -- Spotify client doesn't report its art URL's correctly...
    if player_name == "spotify" then
        artUrl = artUrl:gsub("open.spotify.com", "i.scdn.co")
    end

    if artUrl ~= "" then
        local get_art_script = awful.util.shell .. [[ -c '
            tmp_cover_path=]] .. os.tmpname() .. [[.png
            curl -s ']] .. artUrl .. [[' --output $tmp_cover_path
            echo "$tmp_cover_path"
        ']]

        awful.spawn.with_line_callback(get_art_script, {
            stdout = function(line)
                self:emit_signal("metadata", title, artist, line, player_name,
                                                  album, new)
            end
        })
    else
        self:emit_signal("metadata", title, artist, "", player_name,
                                          album, new)
    end
end

local function metadata_cb(self, player, metadata)
    if update_on_activity then
        manager:move_player_to_top(player)
    end

    local data = metadata.value

    local title = data["xesam:title"] or ""
    local artist = data["xesam:artist"][1] or ""
    for i = 2, #data["xesam:artist"] do
        artist = artist .. ", " .. data["xesam:artist"][i]
    end
    local artUrl = data["mpris:artUrl"] or ""
    local album = data["xesam:album"] or ""

    if player == manager.players[1] then
        -- Callback can be called even though values we care about haven't
        -- changed, so check to see if they have
        if player ~= last_player or title ~= last_title or
            artist ~= last_artist or artUrl ~= last_artUrl
        then
            if (title == "" and artist == "" and artUrl == "") then return end

            if metadata_timer ~= nil and metadata_timer.started then
                metadata_timer:stop()
            end

            metadata_timer = gtimer {
                timeout = debounce_delay,
                autostart = true,
                single_shot = true,
                callback = function()
                    emit_metadata_signal(self, title, artist, artUrl, player.player_name, album, true)
                end
            }

            -- Re-sync with position timer when track changes
            position_timer:again()
            last_player = player
            last_title = title
            last_artist = artist
            last_artUrl = artUrl
        end
    end
end

local function position_cb(self)
    local player = manager.players[1]
    if player then
        local position = player:get_position() / 1000000
        local length = (player.metadata.value["mpris:length"] or 0) / 1000000
        if position ~= last_position or length ~= last_length then
            self:emit_signal("position", position, length, player.player_name)
            last_position = position
            last_length = length
        end
    end
end

local function playback_status_cb(self, player, status)
    if update_on_activity then
        manager:move_player_to_top(player)
    end

    if player == manager.players[1] then
        -- Reported as PLAYING, PAUSED, or STOPPED
        if status == "PLAYING" then
            self:emit_signal("playback_status", true, player.player_name)
        else
            self:emit_signal("playback_status", false, player.player_name)
        end
    end
end

local function volume_cb(self, player, volume)
    if update_on_activity then
        manager:move_player_to_top(player)
    end

    if player == manager.players[1] then
        self:emit_signal("volume", volume, player.volume)
    end
end

local function loop_status_cb(self, player, loop_status)
    if update_on_activity then
        manager:move_player_to_top(player)
    end

    if player == manager.players[1] then
        self:emit_signal("loop_status", loop_status, player.volume)
    end
end

local function shuffle_cb(self, player, shuffle)
    if update_on_activity then
        manager:move_player_to_top(player)
    end

    if player == manager.players[1] then
        self:emit_signal("shuffle", shuffle, player.player_name)
    end
end

-- Determine if player should be managed
local function name_is_selected(name)
    if ignore[name.name] then
        return false
    end

    if #priority > 0 then
        for _, arg in pairs(priority) do
            if arg == name.name or arg == "%any" then
                return true
            end
        end
        return false
    end

    return true
end

-- Create new player and connect it to callbacks
local function init_player(self, name)
    if name_is_selected(name) then
        local player = lgi_Playerctl.Player.new_from_name(name)
        manager:manage_player(player)
        player.on_metadata = function(player, metadata)
            metadata_cb(self, player, metadata)
        end
        player.on_playback_status = function(player, playback_status)
            playback_status_cb(self, player, playback_status)
        end
        player.on_volume = function(player, volume)
            volume_cb(self, player, volume)
        end
        player.on_loop_status = function(player, loop_status)
            loop_status_cb(self, player, loop_status)
        end
        player.on_shuffle = function(player, shuffle_status)
            shuffle_cb(self, player, shuffle_status)
        end

        -- Start position timer if its not already running
        if not position_timer.started then
            position_timer:again()
        end
    end
end

-- Determine if a player name comes before or after another according to the
-- priority order
local function player_compare_name(name_a, name_b)
    local any_index = math.huge
    local a_match_index = nil
    local b_match_index = nil

    if name_a == name_b then
        return 0
    end

    for index, name in ipairs(priority) do
        if name == "%any" then
            any_index = (any_index == math.huge) and index or any_index
        elseif name == name_a then
            a_match_index = a_match_index or index
        elseif name == name_b then
            b_match_index = b_match_index or index
        end
    end

    if not a_match_index and not b_match_index then
        return 0
    elseif not a_match_index then
        return (b_match_index < any_index) and 1 or -1
    elseif not b_match_index then
        return (a_match_index < any_index) and -1 or 1
    elseif a_match_index == b_match_index then
        return 0
    else
        return (a_match_index < b_match_index) and -1 or 1
    end
end

-- Sorting function used by manager if a priority order is specified
local function player_compare(a, b)
    local player_a = lgi_Playerctl.Player(a)
    local player_b = lgi_Playerctl.Player(b)
    return player_compare_name(player_a.player_name, player_b.player_name)
end

local function get_current_player_info(self, player)
    local title = lgi_Playerctl.Player.get_title(player) or ""
    local artist = lgi_Playerctl.Player.get_artist(player) or ""
    local artUrl = lgi_Playerctl.Player.print_metadata_prop(player, "mpris:artUrl") or ""
    local album = lgi_Playerctl.Player.get_album(player) or ""

    emit_metadata_signal(self, title, artist, artUrl, player.player_name, album, true)
    playback_status_cb(self, player, player.playback_status)
    volume_cb(self, player, player.volume)
    loop_status_cb(self, player, player.loop_status)
    shuffle_cb(self, player, player.shuffle)
end

local function start_manager(self)
    manager = lgi_Playerctl.PlayerManager()

    if #priority > 0 then
        manager:set_sort_func(player_compare)
    end

    -- Timer to update track position at specified interval
    position_timer = gtimer {
        timeout = interval,
        callback = function()
            position_cb(self)
        end,
    }

    -- Manage existing players on startup
    for _, name in ipairs(manager.player_names) do
        init_player(self, name)
    end

    if manager.players[1] then
        get_current_player_info(self, manager.players[1])
    end

    local _self = self

    -- Callback to manage new players
    function manager:on_name_appeared(name)
        init_player(_self, name)
    end

    -- Callback to check if all players have exited
    function manager:on_name_vanished(name)
        if #manager.players == 0 then
            metadata_timer:stop()
            position_timer:stop()
            _self:emit_signal("no_players")
        else
            get_current_player_info(_self, manager.players[1])
        end
    end
end

local function parse_args(args)
    if args then
        update_on_activity = args.update_on_activity or update_on_activity
        interval = args.interval or interval
        debounce_delay = args.debounce_delay or debounce_delay

        if type(args.ignore) == "string" then
            ignore[args.ignore] = true
        elseif type(args.ignore) == "table" then
            for _, name in pairs(args.ignore) do
                ignore[name] = true
            end
        end

        if type(args.player) == "string" then
            priority[1] = args.player
        elseif type(args.player) == "table" then
            priority = args.player
        end
    end
end

local function new(args)
    args = args or {}

    -- Grab settings from beautiful variables if not set explicitly
    args.ignore = args.ignore or beautiful.playerctl_ignore
    args.player = args.player or beautiful.playerctl_player
    args.update_on_activity = args.update_on_activity or
                              beautiful.playerctl_update_on_activity
    args.interval = args.interval or beautiful.playerctl_position_update_interval
    args.debounce_delay = args.debounce_delay or beautiful.playerctl_position_update_debounce_delay
    parse_args(args)

    -- Grab playerctl library
    lgi_Playerctl = require("lgi").Playerctl

    local ret = gobject{}
    gtable.crush(ret, playerctl, true)

    -- Ensure main event loop has started before starting player manager
    gtimer.delayed_call(function()
        start_manager(ret)
    end)

    return ret
end

function playerctl.mt:__call(...)
    if not instance then
        instance = new(...)
    end
    return instance
end

return setmetatable(playerctl, playerctl.mt)
