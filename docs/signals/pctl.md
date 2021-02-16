## 🎵 Playerctl <!-- {docsify-ignore} -->

This is a signal module in which you can connect to certain bling signals to grab playerctl info. Currently, this is what it supports:

- Song title and artist
- Album art (the path this module downloaded the art to)
- If playing or not
- Position
- Song length

This module relies on `playerctl` and `curl`. If you have this module disabled, you won't need those programs. With this module, you can create a widget like below without worrying about the backend.

![](https://user-images.githubusercontent.com/33443763/107377569-fa807900-6a9f-11eb-93c1-174c58eb7bf1.png)

*screenshot by [javacafe](https://github.com/JavaCafe01)*

### Usage

To enable: `bling.signal.playerctl.enable()`

Here are the signals available:

```lua
-- bling::playerctl::status     -- first line is the signal
--      playing  (boolean)      -- indented lines are function parameters
-- bling::playerctl::album
--      album_art  (string)
-- bling::playerctl::title_artist
--      title  (string)
--      artist  (string)
-- bling::playerctl::position
--      interval_sec  (number)
--      length_sec  (number)
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

awesome.connect_signal("bling::playerctl::album", function(path)
    art:set_image(gears.surface.load_uncached(path))
end)
```
Thats all! You don't even have to worry about updating the imagebox, the signals will handle that for you.

### Theme Variables
```lua
theme.playerctl_position_update_interval = 1  -- the update interval for fetching the position from playerctl
```
