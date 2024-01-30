## 🏬 Tiled Wallpaper <!-- {docsify-ignore} -->

### Usage

The function to set a tiled wallpaper can be called by the following (not every option is necessary):
```lua
awful.screen.connect_for_each_screen(function(s) -- that way the wallpaper is applied to every screen
    bling.module.tiled_wallpaper("x", s, {       -- call the actual function ("x" is the string that will be tiled)
        fg = "#ff0000", -- define the foreground color
        bg = "#00ffff", -- define the background color
        offset_y = 25,  -- set a y offset
        offset_x = 25,  -- set a x offset
        font = "Hack",  -- set the font (without the size)
        font_size = 14, -- set the font size
        padding = 100,  -- set padding (default is 100)
        zickzack = true -- rectangular pattern or criss cross
    })
end)
```

### Preview

![](https://user-images.githubusercontent.com/70270606/213927382-bdb1b402-0e14-4a00-bfd1-5a1591c71d96.png)

*screenshots by [Nooo37](https://github.com/Nooo37)*

