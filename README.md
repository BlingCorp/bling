# <center> 🌟 Bling - Utilities for the AwesomeWM 🌟 </center>

## ❓ Why

AwesomeWM is literally that - an awesome window manager. 

It's unique selling point has always been the widget system allowing for fancy buttons, sliders, bars, dashboards and everything you can imagine. But that feature might also be a curse. Most modules focus on the widget side of things which left the actual window managing part of awesomeWM a little underdeveloped compared to for example xmonad even though it's probably just as powerfull in that regard. 

This module is trying to fix exactly that: Adding new layouts and modules that - while making use of the widget system - don't focus on it but on new window managing features.

## 🧭 Installation and configuration
- `git clone` this repo into your `~/.config/awesome` folder
- Put ``local bling = require("bling")`` somewhere in your ``rc.lua`` (remember to put it under ``beautiful.init...``)

##### 📎 Layouts

Choose layouts from the list below and add them to to your `awful.layouts` list in your `rc.lua`.

Everyone of them supports multiple master clients and master width factor making them as easily useable as the default layouts.
```Lua
bling.layout.mstab
bling.layout.centered
bling.layout.vertical
bling.layout.horizontal
```

##### 😋 Window swallowing

To activate and deactivate window swallowing there are the following functions. If you want to activate it, just call the `start` function once in your `rc.lua`.
```lua
bling.module.window_swallowing.start()   -- activates window swallowing
bling.module.window_swallowing.stop()    -- deactivates window swallowing
bling.module.window_swallowing.toggle()  -- toggles window swallowing
```

##### 🏬 Tiled Wallpaper 

The function to set an automatically created tiled wallpaper can be called the follwing way (you don't need to set every option in the table of the last argument since there are reasonable defaults):
```lua
awful.screen.connect_for_each_screen(function(s)  -- that way the wallpaper is applied to every screen 
    bling.module.tiled_wallpaper("x", s, {        -- call the actual function ("x" is the string that will be tiled)
        fg = "#ff0000",  -- define the foreground color
        bg = "#00ffff",  -- define the background color
        offset_y = 25,   -- set a y offset
        offset_x = 25,   -- set a x offset
        font = "Hack",   -- set the font (without the size)
        font_size = 14,  -- set the font size
        padding = 100,   -- set padding (default is 100)
        zickzack = true  -- rectangular pattern or criss cross
    })
end)
```

##### 🎇 Wallpaper easy setup

This is a simple-to-use, extensible, declarative wallpaper manager.

###### Practical examples

```lua
-- A default Awesome wallpaper
bling.module.wallpaper.setup()

-- A slideshow with pictures from different sources changing every 30 minutes
bling.module.wallpaper.setup {
    wallpaper = {"/images/my_dog.jpg", "/images/my_cat.jpg"},
    change_timer = 1800
}

-- A random wallpaper with images from multiple folders
bling.module.wallpaper.setup {
    set_function = bling.module.wallpaper.setters.random
    wallpaper = {"/path/to/a/folder", "/path/to/another/folder"},
    change_timer = 631,  -- prime numbers are better for timers
    position = "fit",
    background = "#424242"
}

-- wallpapers based on a schedule, like awesome-glorious-widgets dynamic wallpaper
-- https://github.com/manilarome/awesome-glorious-widgets/tree/master/dynamic-wallpaper
bling.module.wallpaper.setup {
    set_function = wallpaper.setters.simple_schedule,
    wallpaper = {
        ["06:22:00"] = "morning-wallpaper.jpg",
        ["12:00:00"] = "noon-wallpaper.jpg",
        ["17:58:00"] = "night-wallpaper.jpg",
        ["24:00:00"] = "midnight-wallpaper.jpg",
    },
    position = "maximized",
}

-- random wallpapers, from different folder depending on time of the day
bling.module.wallpaper.setup {
    set_function = bling.module.wallpaper.setters.simple_schedule,
    wallpaper = {
        ["09:00:00"] = "~/Pictures/safe_for_work",
        ["18:00:00"] = "~/Pictures/personal",
    },
    schedule_set_function = bling.module.wallpaper.setters.random
    position = "maximized",
    recursive = false,
    change_timer = 600
}
```
###### Details

The setup function will do 2 things: call the set-function when awesome requests a wallpaper, and manage a timer to call `set_function` periodically.

Its argument is a args table that is passed to ohter functions (setters and wallpaper functions), so you define everything with setup.

The `set_function` is a function called every times a wallpaper is needed.

The module provides some setters:

* `bling.module.wallpaper.setters.awesome_wallpaper`: beautiful.theme_assets.wallpaper with defaults from beautiful.
* `bling.module.wallpaper.setters.simple`: slideshow from the `wallpaper` argument.
* `bling.module.wallpaper.setters.random`: same as simple but in a random way.
* `bling.module.wallpaper.setters.simple_schedule`: takes a table of `["HH:MM:SS"] = wallpaper` arguments, where wallpaper is the `wallpaper` argument used by `schedule_set_function`.

A wallpaper is one of the following elements:

* a color
* an image
* a folder containing images
* a function that sets a wallpaper
* everything gears.wallpaper functions can manage (cairo surface, cairo pattern string)
* a list containing any of the elements above
```lua
-- This is a valid wallpaper definition
bling.module.wallpaper.setup {
    wallpaper = {                  -- a list
        "black", "#112233",        -- colors
        "wall1.jpg", "wall2.png",  -- files
        "/path/to/wallpapers",     -- folders
        -- cairo patterns
        "radial:600,50,100:105,550,900:0,#2200ff:0.5,#00ff00:1,#101010",
        -- or functions that set a wallpaper
        function(args) bling.module.tiled_wallpaper("\\o/", args.screen) end,
        bling.module.wallpaper.setters.awesome_wallpaper,
    },
    change_timer = 10,
}
```
The provided setters `simple` and `random` will use 2 internal functions that you can use to write your own setter:

* `bling.module.wallpaper.prepare_list`: return a list of wallpapers directly usable by `apply` (for now, it just explores folders)
* `bling.module.wallpaper.apply`: a wrapper for gears.wallpaper functions, using the args table of setup

Here are the defaults:
```lua
-- Default parameters
bling.module.wallpaper.setup {
    screen = nil,        -- the screen to apply the wallpaper, as seen in gears.wallpaper functions
    change_timer = nil,  -- the timer in seconds. If set, call the set_function every change_timer seconds
    set_function = nil,  -- the setter function

    -- parameters used by bling.module.wallpaper.prepare_list
    wallpaper = nil,                                -- the wallpaper object, see simple or simple_schedule documentation
    image_formats = {"jpg", "jpeg", "png", "bmp"},  -- when searching in folder, consider these files only
    recursive = true,                               -- when searching in folder, search also in subfolders

    -- parameters used by bling.module.wallpaper.apply
    position = nil,                              -- use a function of gears.wallpaper when applicable ("centered", "fit", "maximized", "tiled")
    background = beautiful.bg_normal or "black", -- see gears.wallpaper functions
    ignore_aspect = false,                       -- see gears.wallpaper.maximized
    offset = {x = 0, y = 0},                     -- see gears.wallpaper functions
    scale = 1,                                   -- see gears.wallpaper.centered

    -- parameters that only apply to bling.module.wallpaper.setter.awesome (as a setter or as a wallpaper function)
    colors = {                      -- see beautiful.theme_assets.wallpaper
        bg = beautiful.bg_color,    -- the actual default is this color but darkened or lightned
        fg = beautiful.fg_color,
        alt_fg = beautiful.fg_focus
    }
}
```

Check documentation in [module/wallpaper.lua](module/wallpaper.lua) for more details.


##### 🔦 Flash Focus

There are two ways you can use this module. You can just enable it by calling the `enable()` function:
```lua
bling.module.flash_focus.enable()
```
This connects to the focus signal of a client, which means that the flash focus will activate however you focus the client.

The other way is to call the function itself like this: `bling.module.flash_focus.flashfocus(someclient)`. This allows you to just activate on certain keybinds:
```lua
awful.key({modkey}, "Up",
    function() 
        awful.client.focus.bydirection("up")
        bling.module.flash_focus.flashfocus(client.focus)
     end, {description = "focus up", group = "client"})
```

##### 📑 Tabbing

You should bind these functions to keys in oder to use the tabbed module effectively:
```lua
bling.module.tabbed.pick()            -- picks a client with your cursor to add to the tabbing group
bling.module.tabbed.pop()             -- removes the focused client from the tabbing group
bling.module.tabbed.iter()            -- iterates through the currently focused tabbing group
bling.module.tabbed.pick_with_dmenu() -- picks a client with a dmenu application (defaults to rofi, other options can be set with a string parameter like "dmenu")
```

##### 🎵 Playerctl

This is a signal module in which you can connect to certain bling signals to grab playerctl info. Currently, this is what it supports:

- Song title and artist
- Album art (the path this module downloaded the art to)
- If playing or not
- Position
- Song length

This module relies on `playerctl` and `curl`. If you have this module disabled, you won't need those programs.

To enable: `bling.signal.playerctl.enable()`

###### Signals

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

###### Example Implementation

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



### 🌈 Theme variables
You will find a list of all theme variables that are used in bling and comments on what they do in the `theme-var-template.lua` file - ready for you to copy them into your `theme.lua`. Theme variables are not only used to change the appearance of some features but also to adjust the functionality of some modules. So it is worth it to take a look at them.

## 😲 Preview

### Tabbing
![](https://imgur.com/08AlNhQ.png)

screenshot by [javacafe](https://github.com/JavaCafe01)

### Mstab (dynamic tabbing layout)
![](https://imgur.com/HZRgApE.png)

screenshot by [javacafe](https://github.com/JavaCafe01)

### Centered
![](https://media.discordapp.net/attachments/769673106842845194/780095998239834142/unknown.png)

screenshot by [branwright](https://github.com/branwright1)

### Tiled Wallpaper
![](https://media.discordapp.net/attachments/702548913999314964/773887721294135296/tiled-wallpapers.png?width=1920&height=1080)

screenshots by me

### Flash Focus
![](https://imgur.com/5txYrlV.gif)

gif by [javacafe](https://github.com/JavaCafe01)

### Wind swallowing
![](https://media.discordapp.net/attachments/635625813143978012/769180910683684864/20-10-23-14-40-32.gif)

gif by me :)

### Playerctl Signals Implementation
![](https://user-images.githubusercontent.com/33443763/107377569-fa807900-6a9f-11eb-93c1-174c58eb7bf1.png)

screenshot by [javacafe](https://github.com/JavaCafe01)

## TODO
- [ ] Add external sources management for the wallpaper module (URLs, RSS feeds, NASA picture of the day, ...)
- [ ] Scratchpad module
- [x] Some more documentation on the tabbed module
- [x] Add a cool alternative tabbar style  
- [x] Add another cool tabbar style (we need more styles)
- [x] Make the mstab layout compatible with vertical tabbars (left and right)
- [x] Add option to mstab layout to not shrink windows down when they are in the tabbed pane and unfocused (for example for people using transparent terminals)
- [x] Keyboard based option to add windows to a tabbing object

All naming credit goes to javacafe.

Contributions are welcomed 💛
