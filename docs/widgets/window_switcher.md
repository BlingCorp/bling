## 🎨 Window Switcher <!-- {docsify-ignore} -->

A popup with client previews that allows you to switch clients similar to the alt-tab menu in MacOS, GNOME, and Windows.

![](https://user-images.githubusercontent.com/70270606/133311802-8aef1012-346f-4f4c-843d-10d9de54ffeb.png)

*image by [No37](https://github.com/Nooo37)*

### Usage

To enable:

```lua
bling.widget.window_switcher.enable {
    type = "thumbnail", -- set to anything other than "thumbnail" to disable client previews

    -- keybindings (the examples provided are also the default if kept unset)
    hide_window_switcher_key = "Escape", -- The key on which to close the popup
    minimize_key = "n",     -- The key on which to minimize the selected client
    unminimize_key = "N",   -- The key on which to unminimize all clients
    kill_client_key = "q",  -- The key on which to close the selected client
    cycle_key = "Tab",      -- The key on which to cycle through all clients
    previous_key = "Left",  -- The key on which to select the previous client
    next_key = "Right",     -- The key on which to select the next client
    vim_previous_key = "h", -- Alternative key on which to select the previous client
    vim_next_key = "l",     -- Alternative key on which to select the next client
}
```

To run the window swicher you have to emit this signal from within your configuration (usually using a keybind).

```lua
awesome.emit_signal("bling::window_switcher::turn_on")
```

For example:
```lua
 awful.key({altkey}, "Tab", function()
            awesome.emit_signal("bling::window_switcher::turn_on")
        end, {description = "Window Switcher", group = "client"})
```
