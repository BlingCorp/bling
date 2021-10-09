-- Playerctl signals
--
-- Provides:
-- metadata
--      title (string)
--      artist  (string)
--      album_path (string)
--      player_name (string)
--      album (string)
-- position
--      interval_sec (number)
--      length_sec (number)
-- playback_status
--      playing (boolean)
-- volume
--      volume (number)
-- loop_status
--      loop_status (string)
-- shuffle
--      shuffle (bool)
-- no_players
--      (No parameters)

local awful = require("awful")
local gobject = require("gears.object")
local gtable = require("gears.table")
local gtimer = require("gears.timer")
local gstring = require("gears.string")
local beautiful = require("beautiful")
local setmetatable = setmetatable
local tonumber = tonumber
local pairs = pairs
local type = type

local playerctl = { mt = {} }

function playerctl:disable()
    self._private.metadata_timer:stop()
    self._private.metadata_timer = nil
    awful.spawn.with_shell("pkill --full --uid " .. os.getenv("USER") ..
                               " '^playerctl status -F'")
    awful.spawn.with_shell("pkill --full --uid " .. os.getenv("USER") ..
                               " '^playerctl metadata --format'")
end

function playerctl:pause()
    awful.spawn.with_shell(self._private.cmd .. "pause")
end

function playerctl:play()
    awful.spawn.with_shell(self._private.cmd .. "play")
end

function playerctl:stop()
    awful.spawn.with_shell(self._private.cmd .. "stop")
end

function playerctl:play_pause()
    awful.spawn.with_shell(self._private.cmd .. "play-pause")
end

function playerctl:previous()
    awful.spawn.with_shell(self._private.cmd .. "previous")
end

function playerctl:next()
    awful.spawn.with_shell(self._private.cmd .. "next")
end

function playerctl:set_loop_status(loop_status)
    awful.spawn.with_shell(self._private.cmd .. "loop " .. loop_status)
end

function playerctl:cycle_loop_status()
    if self._private.loop_status == "None" then
        self:set_loop_status("Track")
    elseif self._private.loop_status == "Track" then
        self:set_loop_status("Playlist")
    elseif self._private.loop_status == "Playlist" then
        self:set_loop_status("None")
    end
end

function playerctl:set_position(position)
    awful.spawn.with_shell(self._private.cmd .. "position " .. position)
end

function playerctl:set_shuffle(shuffle)
    if shuffle == true then
        shuffle = "on"
    else
        shuffle = "off"
    end

    awful.spawn.with_shell(self._private.cmd .. "shuffle " .. shuffle)
end

function playerctl:cycle_shuffle()
    if self._private.shuffle == false then
        self:set_shuffle(true)
    elseif self._private.shuffle == true then
        self:set_shuffle(false)
    end
end

function playerctl:set_volume(volume)
    awful.spawn.with_shell(self._private.cmd .. "next" .. volume)
end

local function emit_player_metadata(self)
    local metadata_cmd = self._private.cmd .. "metadata --format 'title_{{title}}artist_{{artist}}art_url_{{mpris:artUrl}}player_name_{{playerName}}album_{{album}}' -F"

    awful.spawn.with_line_callback(metadata_cmd, {
        stdout = function(line)
            local title = gstring.xml_escape(line:match('title_(.*)artist_')) or ""
            local artist = gstring.xml_escape(line:match('artist_(.*)art_url_')) or ""
            local art_url = line:match('art_url_(.*)player_name_') or ""
            local player_name = line:match('player_name_(.*)album_') or ""
            local album = gstring.xml_escape(line:match('album_(.*)')) or ""

            art_url = art_url:gsub('%\n', '')
            if player_name == "spotify" then
                art_url = art_url:gsub("open.spotify.com", "i.scdn.co")
            end

            if self._private.metadata_timer ~= nil
                and self._private.metadata_timer.started
            then
                self._private.metadata_timer:stop()
            end

            self._private.metadata_timer = gtimer {
                timeout = self.debounce_delay,
                autostart = true,
                single_shot = true,
                callback = function()
                    if title and title ~= "" then
                        if art_url ~= "" then
                            local get_art_script = awful.util.shell .. [[ -c '
                                tmp_cover_path=]] .. os.tmpname() .. [[.png
                                curl -s ']] .. art_url .. [[' --output $tmp_cover_path
                                echo "$tmp_cover_path"
                            ']]

                            awful.spawn.with_line_callback(get_art_script, {
                                stdout = function(stdout)
                                    self:emit_signal("metadata", title, artist,
                                                    stdout, player_name, album)
                                end
                            })
                        else
                            self:emit_signal("metadata", title, artist, "",
                                                        player_name, album)
                        end
                    else
                        self:emit_signal("no_players")
                    end
                end
            }

            collectgarbage("collect")
        end,
    })
end

local function emit_player_position(self)
    local position_cmd = self._private.cmd .. "position"
    local length_cmd = self._private.cmd .. "metadata mpris:length"

    awful.widget.watch(position_cmd, self.interval, function(_, interval)
        awful.spawn.easy_async_with_shell(length_cmd, function(length)
            local length_sec = tonumber(length) -- in microseconds
            local interval_sec = tonumber(interval) -- in seconds
            if length_sec and interval_sec then
                if interval_sec >= 0 and length_sec > 0 then
                    self:emit_signal("position", interval_sec, length_sec / 1000000)
                end
            end
        end)
        collectgarbage("collect")
    end)
end

local function emit_player_playback_status(self)
    local status_cmd = self._private.cmd .. "status -F"

    awful.spawn.with_line_callback(status_cmd, {
        stdout = function(line)
            if line:find("Playing") then
                self:emit_signal("playback_status", true)
            else
                self:emit_signal("playback_status", false)
            end
        end,
    })
end

local function emit_player_volume(self)
    local volume_cmd = self._private.cmd .. "volume -F"

    awful.spawn.with_line_callback(volume_cmd, {
        stdout = function(line)
            self:emit_signal("volume", tonumber(line))
        end,
    })
end

local function emit_player_loop_status(self)
    local loop_status_cmd = self._private.cmd .. "loop -F"

    awful.spawn.with_line_callback(loop_status_cmd, {
        stdout = function(line)
            self._private.loop_status = line
            self:emit_signal("loop_status", line:lower())
        end,
    })
end

local function emit_player_shuffle(self)
    local shuffle_cmd = self._private.cmd .. "shuffle -F"

    awful.spawn.with_line_callback(shuffle_cmd, {
        stdout = function(line)
            if line:find("On") then
                self._private.shuffle = true
                self:emit_signal("shuffle", true)
            else
                self._private.shuffle = false
                self:emit_signal("shuffle", false)
            end
        end,
    })
end

local function parse_args(self, args)
    if args.player then
        self._private.cmd = self._private.cmd .. "--player="

        if type(args.player) == "string" then
            self._private.cmd = self._private.cmd .. args.player .. " "
        elseif type(args.player) == "table" then
            for index, player in pairs(args.player) do
                self._private.cmd = self._private.cmd .. player
                if index < #args.player then
                    self._private.cmd = self._private.cmd .. ","
                else
                    self._private.cmd = self._private.cmd .. " "
                end
            end
        end
    end

    if args.ignore then
        self._private.cmd = self._private.cmd .. "--ignore-player="

        if type(args.ignore) == "string" then
            self._private.cmd = self._private.cmd .. args.ignore .. " "
        elseif type(args.ignore) == "table" then
            for index, player in pairs(args.ignore) do
                self._private.cmd = self._private.cmd .. player
                if index < #args.ignore then
                    self._private.cmd = self._private.cmd .. ","
                else
                    self._private.cmd = self._private.cmd .. " "
                end
            end
        end
    end
end

local function new(args)
    args = args or {}

    local ret = gobject{}
    gtable.crush(ret, playerctl, true)

    ret.interval = args.interval or beautiful.playerctl_position_update_interval or 1
    ret.debounce_delay = args.debounce_delay or beautiful.playerctl_debounce_delay or 0.35

    ret._private = {}
    ret._private.metadata_timer = nil
    ret._private.cmd = "playerctl "
    parse_args(ret, args)

    emit_player_metadata(ret)
    emit_player_position(ret)
    emit_player_playback_status(ret)
    emit_player_volume(ret)
    emit_player_loop_status(ret)
    emit_player_shuffle(ret)

    return ret
end

function playerctl.mt:__call(...)
    return new(...)
end

-- On startup instead of on playerctl object init to make it
-- possible to have more than one of these running
awful.spawn.with_shell("killall playerctl")

return setmetatable(playerctl, playerctl.mt)
