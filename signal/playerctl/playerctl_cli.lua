--
-- Provides:
-- bling::playerctl::status
--      playing (boolean)
-- bling::playerctl::title_artist_album
--      title (string)
--      artist    (string)
--      album_path (string)
-- bling::playerctl::position
--      interval_sec (number)
--      length_sec (number)
-- bling::playerctl::no_players
--
local awful = require("awful")
local gears = require("gears")
local beautiful = require("beautiful")

local interval = beautiful.playerctl_position_update_interval or 1

local function emit_player_status()
    local status_cmd = "playerctl status -F"

    -- Follow status
    awful.spawn.easy_async({
        "pkill", "--full", "--uid", os.getenv("USER"), "^playerctl status"
    }, function()
        awful.spawn.with_line_callback(status_cmd, {
            stdout = function(line)
                local playing = false
                if line:find("Playing") then
                    playing = true
                else
                    playing = false
                end
                awesome.emit_signal("bling::playerctl::status", playing)
            end
        })
        collectgarbage("collect")
    end)
end

local function get_album_art(url)
    return awful.util.shell .. [[ -c '

tmp_dir="$XDG_CACHE_HOME/awesome/"

if [ -z "$XDG_CACHE_HOME" ]; then
    tmp_dir="$HOME/.cache/awesome/"
fi

tmp_cover_path="${tmp_dir}cover.png"

if [ ! -d "$tmp_dir" ]; then
    mkdir -p $tmp_dir
fi

curl -s ']] .. url .. [[' --output $tmp_cover_path

echo "$tmp_cover_path"
']]
end

local function emit_player_info()
    -- Command that lists artist and title in a format to find and follow
    local song_follow_cmd =
        "playerctl metadata --format 'title_{{title}}artist_{{artist}}art_url_{{mpris:artUrl}}player_name_{{playerName}}album_{{album}}' -F"

    -- Progress Cmds
    local prog_cmd = "playerctl position"
    local length_cmd = "playerctl metadata mpris:length"

    awful.widget.watch(prog_cmd, interval, function(_, interval)
        awful.spawn.easy_async_with_shell(length_cmd, function(length)
            local length_sec = tonumber(length) -- in microseconds
            local interval_sec = tonumber(interval) -- in seconds
            if length_sec and interval_sec then
                if interval_sec >= 0 and length_sec > 0 then
                    awesome.emit_signal("bling::playerctl::position",
                                        interval_sec, length_sec / 1000000)
                end
            end
        end)
        collectgarbage("collect")
    end)

    -- Follow title
    awful.spawn.easy_async({
        "pkill", "--full", "--uid", os.getenv("USER"), "^playerctl metadata"
    }, function()
        awful.spawn.with_line_callback(song_follow_cmd, {
            stdout = function(line)
                local title = gears.string.xml_escape(line:match('title_(.*)artist_')) or ""
                local artist = gears.string.xml_escape(line:match('artist_(.*)art_url_')) or ""
                local art_url = line:match('art_url_(.*)player_name_') or ""
                local player_name = line:match('player_name_(.*)album_') or ""
                local album = gears.string.xml_escape(line:match('album_(.*)')) or ""

                art_url = art_url:gsub('%\n', '')
                if player_name == "spotify" then
                    art_url = art_url:gsub("open.spotify.com", "i.scdn.co")
                end

                if title and title ~= "" then
                    if art_url ~= "" then
                        awful.spawn.with_line_callback(get_album_art(art_url), {
                            stdout = function(line)
                                awesome.emit_signal(
                                    "bling::playerctl::title_artist_album",
                                    title,
                                    artist,
                                    line,
                                    player_name,
                                    album
                                )
                            end
                        })
                    else
                        awesome.emit_signal(
                            "bling::playerctl::title_artist_album",
                            title,
                            artist,
                            "",
                            player_name,
                            album
                        )
                    end
                else
                    awesome.emit_signal("bling::playerctl::no_players")
                end

                collectgarbage("collect")
            end
        })
        collectgarbage("collect")
    end)
end

-- Emit info
-- emit_player_status()
-- emit_player_info()

local enable = function(args)
    interval = (args and args.interval) or interval
    emit_player_status()
    emit_player_info()
end

local disable = function()
    awful.spawn.with_shell("pkill --full --uid " .. os.getenv("USER") ..
                               " '^playerctl status -F'")

    awful.spawn.with_shell("pkill --full --uid " .. os.getenv("USER") ..
                               " '^playerctl metadata --format'")
end

return {enable = enable, disable = disable}
