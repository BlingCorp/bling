## 😋 Window Swallowing <!-- {docsify-ignore} -->

Can your window manager swallow? It probably can...

### Usage

To activate and deactivate window swallowing here are the following functions. If you want to activate it, just call the `start` function once in your `rc.lua`.
```lua
bling.module.window_swallowing.start()   -- activates window swallowing
bling.module.window_swallowing.stop()    -- deactivates window swallowing
bling.module.window_swallowing.toggle()  -- toggles window swallowing
```

### Theme Variables
```lua
theme.dont_swallow_classname_list    = {"firefox", "Gimp"}      -- list of class names that should not be swallowed
theme.dont_swallow_filter_activated  = true                     -- whether the filter above should be active
```

### Preview

![](https://media.discordapp.net/attachments/635625813143978012/769180910683684864/20-10-23-14-40-32.gif)

*gif by [Nooo37](https://github.com/Nooo37)*
