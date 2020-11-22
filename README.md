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

Everyone of them supports multiple master clients and master width factor making them as easyily useable as the default layouts.
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
bling.module.tabbed.pick()  -- makes you pick a client with your mouse to add to the tabbing group
bling.module.tabbed.pop()   -- removes the focused client from the tabbing group
bling.module.tabbed.iter()  -- iterates through the currently focused tabbing group
```


### 🌈 Theme variables
Put those variables in your ``theme.lua`` if you want to edit appearance and some functionalities.

For the **mstab layout**:
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

For **window swallowing**:
```lua
dont_swallow_classname_list   -- list of client classnames that shouldn't be swallowed
                              -- default is {"firefox", "Gimp"}
dont_swallow_filter_activated -- whether the filter is activated or not
                              -- default is false.
                              -- Set it to true if you want to filter clients that should be swallowed
```


For **flash focus**:
```lua
flash_focus_start_opacity -- the starting opacity (default 0.6)
flash_focus_step          -- the step of the animation (default 0.01)
```

For **tabbed**:
```lua
tabbed_spawn_into_tab     -- set to true if you want new windows to spawn into your focused tabbing

```

## 😲 Preview

### Mstab (dynamic tabbing layout)
![](https://media.discordapp.net/attachments/716379882363551804/769870675250249808/shot_1025032923.png)

<p align="center">screenshot by [javacafe](https://github.com/JavaCafe01)</p>

### Centered
![](https://media.discordapp.net/attachments/635625917623828520/768947400554446868/centered.png)

<p align="center">screenshot by [branwright](https://github.com/branwright1)</p>

### Tiled Wallpaper
![](https://media.discordapp.net/attachments/702548913999314964/773887721294135296/tiled-wallpapers.png?width=1920&height=1080)

<p align="center">screenshots by me</p>

### Flash Focus
![](https://imgur.com/5txYrlV.gif)

<p align="center">git by [javacafe](https://github.com/JavaCafe01)</p>

### Wind swallowing
![](https://media.discordapp.net/attachments/635625813143978012/769180910683684864/20-10-23-14-40-32.gif)

<p align="center">gif by me :)</p>

## TODO
- [ ] Scratchpad module
- [ ] Some more documentation on the tabbed module
- [x] Add a cool alternative tabbar style  
- [ ] Add another cool tabbar style (we need more styles)
- [ ] Make the mstab layout compatible with vertical tabbars (left and right)
- [ ] Add option to mstab layout to not shrink windows down when they are in the tabbed pane and unfocused (for example for people using transparent terminals)

All naming credit goes to javacafe.

Contributions are welcomed 💛
