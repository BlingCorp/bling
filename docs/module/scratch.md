## 🍃 Scratchpad <!-- {docsify-ignore} -->

An easy way for creating multiple scratchpads.

### A... what?

You can think about a scratchpad as a window whose visibility you can toggle off and on but which just runs in the background without being visible (or minimized) most of the time. Many people use it to have one terminal in which to perform minor tasks but it is in general useful for windows which you only need a couple seconds in between your actual activity such as music players or chat applications. 

### Usage

To initalize a scratchpad you can do something like the following:

```lua
local bling = require("bling")

local term_scratch = bling.module.scratchpad:new { 
    command = "wezterm start --class spad", -- How to spawn the scratchpad
    rule = { instance = "spad" },           -- The rule that the scratchpad will be searched by
    sticky = true,                          -- Whether the scratchpad should be sticky
    autoclose = true,                       -- Whether it should hide itself when losing focus
    floating = true,                        -- Whether it should be floating
    geometry = {x=360, y=90, height=900, width=1200}, -- The geometry in a floating state
    reapply = false, -- Whether all those properties should be reapplied on every new opening of the scratchpad
}
```

Once initalized, you can use the object (which in this case is named `term_scratch`) like that:

```lua
term_scratch:toggle()   -- toggles the scratchpads visibility
term_scratch:turn_on()  -- turns the scratchpads visibility off
term_scratch:turn_off() -- turns the scratchpads visibility on
```
