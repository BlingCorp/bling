-- Playerctl signals
--
-- Provides:
-- bling::playerctl::status
--      playing (boolean)
--      player_name (string)
-- bling::playerctl::title_artist_album
--      title (string)
--      artist  (string)
--      album_path (string)
--      player_name (string)
-- bling::playerctl::position
--      interval_sec (number)
--      length_sec (number)
--      player_name (string)
-- bling::playerctl::no_players
--      (No parameters)

local gears = require("gears")
local awful = require("awful")
local beautiful = require("beautiful")
local Playerctl = nil

local manager = nil
local metadata_timer = nil
local position_timer = nil

local ignore = {}
local priority = {}
local update_on_activity = true
local interval = 1

-- Track position callback
local last_position = -1
local last_length = -1
local function position_cb()
    local player = manager.players[1]
    if player then
        local position = player:get_position() / 1000000
        local length = (player.metadata.value["mpris:length"] or 0) / 1000000
        if position ~= last_position or length ~= last_length then
            awesome.emit_signal(
                "bling::playerctl::position",
                position,
                length,
                player.player_name
            )
            last_position = position
            last_length = length
        end
    end
end

local function get_album_art(url)
    return awful.util.shell
        .. [[ -c '

tmp_dir="$XDG_CACHE_HOME/awesome/"

if [ -z "$XDG_CACHE_HOME" ]; then
    tmp_dir="$HOME/.cache/awesome/"
fi

tmp_cover_path="${tmp_dir}cover.png"

if [ ! -d "$tmp_dir" ]; then
    mkdir -p $tmp_dir
fi

curl -s ']]
        .. url
        .. [[' --output $tmp_cover_path

echo "$tmp_cover_path"
']]
end

-- Metadata callback for title, artist, and album art
local last_player = nil
local last_title = ""
local last_artist = ""
local last_artUrl = ""
local function metadata_cb(player, metadata)
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
    -- Spotify client doesn't report its art URL's correctly...
    if player.player_name == "spotify" then
        artUrl = artUrl:gsub("open.spotify.com", "i.scdn.co")
    end

    if player == manager.players[1] then
        -- Callback can be called even though values we care about haven't
        -- changed, so check to see if they have
        if
            player ~= last_player
            or title ~= last_title
            or artist ~= last_artist
            or artUrl ~= last_artUrl
        then
            if title == "" and artist == "" and artUrl == "" then
                return
            end

            if metadata_timer ~= nil then
                if metadata_timer.started then
                    metadata_timer:stop()
                end
            end

            metadata_timer = gears.timer({
                timeout = 0.3,
                autostart = true,
                single_shot = true,
                callback = function()
                    if artUrl ~= "" then
                        awful.spawn.with_line_callback(get_album_art(artUrl), {
                            stdout = function(line)
                                awesome.emit_signal(
                                    "bling::playerctl::title_artist_album",
                                    title,
                                    artist,
                                    line,
                                    player.player_name
                                )
                            end,
                        })
                    else
                        awesome.emit_signal(
                            "bling::playerctl::title_artist_album",
                            title,
                            artist,
                            "",
                            player.player_name
                        )
                    end
                end,
            })

            -- Re-sync with position timer when track changes
            position_timer:again()
            last_player = player
            last_title = title
            last_artist = artist
            last_artUrl = artUrl
        end
    end
end

-- Playback status callback
-- Reported as PLAYING, PAUSED, or STOPPED
local function playback_status_cb(player, status)
    if update_on_activity then
        manager:move_player_to_top(player)
    end

    if player == manager.players[1] then
        if status == "PLAYING" then
            awesome.emit_signal(
                "bling::playerctl::status",
                true,
                player.player_name
            )
        else
            awesome.emit_signal(
                "bling::playerctl::status",
                false,
                player.player_name
            )
        end
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
local function init_player(name)
    if name_is_selected(name) then
        local player = Playerctl.Player.new_from_name(name)
        manager:manage_player(player)
        player.on_playback_status = playback_status_cb
        player.on_metadata = metadata_cb

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
    local player_a = Playerctl.Player(a)
    local player_b = Playerctl.Player(b)
    return player_compare_name(player_a.player_name, player_b.player_name)
end

local function start_manager()
    manager = Playerctl.PlayerManager()
    if #priority > 0 then
        manager:set_sort_func(player_compare)
    end

    -- Timer to update track position at specified interval
    position_timer = gears.timer({
        timeout = interval,
        callback = position_cb,
    })

    -- Manage existing players on startup
    for _, name in ipairs(manager.player_names) do
        init_player(name)
    end

    -- Callback to manage new players
    function manager:on_name_appeared(name)
        init_player(name)
    end

    -- Callback to check if all players have exited
    function manager:on_name_vanished(name)
        if #manager.players == 0 then
            metadata_timer:stop()
            position_timer:stop()
            awesome.emit_signal("bling::playerctl::no_players")
        end
    end
end

-- Parse arguments
local function parse_args(args)
    if args then
        update_on_activity = args.update_on_activity or update_on_activity
        interval = args.interval or interval

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

local function playerctl_enable(args)
    args = args or {}
    -- Grab settings from beautiful variables if not set explicitly
    args.ignore = args.ignore or beautiful.playerctl_ignore
    args.player = args.player or beautiful.playerctl_player
    args.update_on_activity = args.update_on_activity
        or beautiful.playerctl_update_on_activity
    args.interval = args.interval
        or beautiful.playerctl_position_update_interval
    parse_args(args)

    -- Grab playerctl library
    Playerctl = require("lgi").Playerctl

    -- Ensure main event loop has started before starting player manager
    gears.timer.delayed_call(start_manager)
end

local function playerctl_disable()
    -- Remove manager and timer
    manager = nil
    metadata_timer:stop()
    metadata_timer = nil
    position_timer:stop()
    position_timer = nil
    -- Restore default settings
    ignore = {}
    priority = {}
    update_on_activity = true
    interval = 1
    -- Reset default values
    last_position = -1
    last_length = -1
    last_player = nil
    last_title = ""
    last_artist = ""
    last_artUrl = ""
end

return { enable = playerctl_enable, disable = playerctl_disable }
