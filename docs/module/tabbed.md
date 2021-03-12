## 📑 Tabbed <!-- {docsify-ignore} -->

Tabbed implements a tab container. There are also different themes for the tabs.

### Usage

You should bind these functions to keys in order to use the tabbed module effectively:
```lua
bling.module.tabbed.pick()            -- picks a client with your cursor to add to the tabbing group
bling.module.tabbed.pop()             -- removes the focused client from the tabbing group
bling.module.tabbed.iter()            -- iterates through the currently focused tabbing group
bling.module.tabbed.pick_with_dmenu() -- picks a client with a dmenu application (defaults to rofi, other options can be set with a string parameter like "dmenu")
```

### Theme Variables

```lua
-- For tabbed only
theme.tabbed_spawn_in_tab = false           -- whether a new client should spawn into the focused tabbing container 

-- For tabbar in general
theme.tabbar_ontop  = false
theme.tabbar_radius = 0                     -- border radius of the tabbar
theme.tabbar_style = "default"              -- style of the tabbar ("default", "boxes" or "modern")
theme.tabbar_font = "Sans 11"               -- font of the tabbar
theme.tabbar_size = 40                      -- size of the tabbar
theme.tabbar_position = "top"               -- position of the tabbar
theme.tabbar_bg_normal = "#000000"          -- background color of the focused client on the tabbar
theme.tabbar_fg_normal = "#ffffff"          -- foreground color of the focused client on the tabbar
theme.tabbar_bg_focus  = "#1A2026"          -- background color of unfocused clients on the tabbar
theme.tabbar_fg_focus  = "#ff0000"          -- foreground color of unfocused clients on the tabbar

-- the following variables are currently only for the "modern" tabbar style 
theme.tabbar_color_close = "#f9929b"        -- chnges the color of the close button
theme.tabbar_color_min   = "#fbdf90"        -- chnges the color of the minimize button
theme.tabbar_color_float = "#ccaced"        -- chnges the color of the float button
```

### Preview 

Modern theme:

<img src="https://imgur.com/omowmIQ.png" width="600"/>

*screenshot by [javacafe](https://github.com/JavaCafe01)*
