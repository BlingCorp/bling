## 🎵 Playerctl <!-- {docsify-ignore} -->

This is a signal module in which you can connect to certain bling signals to grab playerctl info. Currently, this is what it supports:

- Song title and artist
- Album art (the path this module downloaded the art to)
- If playing or not
- Position
- Song length
- If there are no players on

This module relies on `playerctl` and `curl`. If you have this module disabled, you won't need those programs. With this module, you can create a widget like below without worrying about the backend.

![](https://user-images.githubusercontent.com/33443763/107377569-fa807900-6a9f-11eb-93c1-174c58eb7bf1.png)

*screenshot by [javacafe](https://github.com/JavaCafe01)*

### Usage

To enable: `bling.signal.playerctl.enable()`

Here are the signals available:

```lua
-- bling::playerctl::status     -- first line is the signal
--      playing  (boolean)      -- indented lines are function parameters
-- bling::playerctl::title_artist_album
--      title  (string)
--      artist  (string)
--      album_path (string)
-- bling::playerctl::position
--      interval_sec  (number)
--      length_sec  (number)
-- bling::playerctl::player_stopped
--      (No params)
```

### Example Implementation

Lets say we have an imagebox. If I wanted to set the imagebox to show the album art, all I have to do is this:
```lua
local art = wibox.widget {
    image = "default_image.png",
    resize = true,
    forced_height = dpi(80),
    forced_width = dpi(80),
    widget = wibox.widget.imagebox
}

local title_widget = wibox.widget {
    markup = 'Nothing Playing',
    align = 'center',
    valign = 'center',
    widget = wibox.widget.textbox
}

local artist_widget = wibox.widget {
    markup = 'Nothing Playing',
    align = 'center',
    valign = 'center',
    widget = wibox.widget.textbox
}

-- Get Song Info
awesome.connect_signal("bling::playerctl::title_artist_album",
                       function(title, artist, art_path)
    -- Set art widget
    art:set_image(gears.surface.load_uncached(art_path))

    -- Set title and artist widgets
    title_widget:set_markup_silently(title)
    artist_widget:set_markup_silently(artist)
end)
```
Thats all! You don't even have to worry about updating the widgets, the signals will handle that for you.

Here's another example in which you get a notification with the album art, title, and artist whenever the song changes.

```lua
local naughty = require("naughty")

awesome.connect_signal("bling::playerctl::title_artist_album",
                       function(title, artist, art_path)
    naughty.notify({title = title, text = artist, image = art_path})
end)
```

### Theme Variables
```lua
theme.playerctl_position_update_interval = 1  -- the update interval for fetching the position from playerctl
```
