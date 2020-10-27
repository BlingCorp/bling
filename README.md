# Bling - Utilities for the AwesomeWM

## Installation and configuration
- `git clone` this repo into your `~/.config/awesome` folder
- Put ``local bling = require("bling")`` somewhere in your ``rc.lua`` (remember to put it under ``beautiful.init...``)

### Available layouts and modules

##### Layouts

Choose layouts from the list below and add them to to your `awful.layouts` list in your `rc.lua`.

Everyone of them supports multiple master clients and master width factor making them as easyily useable as the default layouts.
```Lua
bling.layout.mstab
bling.layout.centered
bling.layout.vertical
bling.layout.horizontal
```

##### Window swallowing

To activate and deactivate window swallowing there are the following functions (deactivated on default):
```lua
bling.module.window_swallowing.start()   -- activates window swallowing
bling.module.window_swallowing.stop()    -- deactivates window swallowing
bling.module.window_swallowing.toggle()  -- toggles window swallowing
```

##### Tiled Wallpaper 

The function to set a tiled wallpaper can be called the follwing way (you don't need to set every option in the table of the last argument since there are reasonable defaults):
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

### Theme variables
Put those variables in your ``theme.lua`` if you want to edit appearance

For the mstab layout:
```lua
mstab_tabbar_orientation  -- set to "bottom" for tabbar at button
mstab_bar_height          -- height of the tabbar
mstab_border_radius       -- corners radius of the tabbar
mstab_font                -- font of the tabbar
mstab_bg_focus            -- background color of the focused client on the tabbar
mstab_fg_focus            -- background color of the focused client on the tabbar
mstab_bg_normal           -- foreground color of unfocused clients on the tabbar
mstab_fg_normal           -- foreground color of unfocused clients on the tabbar
```

For window swallowing:
```lua
dont_swallow_classname_list   -- list of client classnames that shouldn't be swallowed
                              -- default is {"firefox", "Gimp"}
dont_swallow_filter_activated -- whether the filter is activated or not
                              -- default is false.
                              -- Set it to true if you want to filter clients that should be swallowed
```

## Preview

### Mstab (tabbed)
![](https://media.discordapp.net/attachments/716379882363551804/769870675250249808/shot_1025032923.png)

screenshot by [javacafe](https://github.com/JavaCafe01)

### Centered
![](https://media.discordapp.net/attachments/635625917623828520/768947400554446868/centered.png)

screenshot by [branwright](https://github.com/branwright1)

### Window swallowing
![](https://media.discordapp.net/attachments/635625813143978012/769180910683684864/20-10-23-14-40-32.gif)

gif by me :)

### Tiled Wallpaper


