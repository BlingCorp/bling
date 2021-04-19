## 🍃 Scratchpad <!-- {docsify-ignore} -->

An easy way to create multiple scratchpads.

### A... what?

You can think about a scratchpad as a window whose visibility can be toggled, but still runs in the background without being visible (or minimized) most of the time. Many people use it to have one terminal in which to perform minor tasks, but it is the most useful for windows which only need a couple seconds in between your actual activity, such as music players or chat applications.

### Awestore Animation Support

To use [awestore](https://github.com/K4rakara/awestore) for animations, you must first install it with `luarocks`.
```bash
sudo luarocks --lua-version 5.3 install awestore
```
The animations are completely optional, and if you chose not to use it, you do not need awestore installed.

### Usage

To initalize a scratchpad you can do something like the following:

```lua
local bling = require("bling")
local awestore = require("awestore")                  -- Totally optional, only required if you are using animations. 

-- These are example awestore tween stores. You can use one for just y, just x, or both. 
-- The duration and easing is up to you. Please check out the awestore docs to learn more.
local anim_y = awestore.tweened(1100, {
    duration = 300,
    easing = awestore.easing.cubic_in_out
})

local anim_x = awestore.tweened(1920, {
    duration = 300,
    easing = awestore.easing.cubic_in_out
})

local term_scratch = bling.module.scratchpad:new { 
    command = "wezterm start --class spad",           -- How to spawn the scratchpad
    rule = { instance = "spad" },                     -- The rule that the scratchpad will be searched by
    sticky = true,                                    -- Whether the scratchpad should be sticky
    autoclose = true,                                 -- Whether it should hide itself when losing focus
    floating = true,                                  -- Whether it should be floating
    geometry = {x=360, y=90, height=900, width=1200}, -- The geometry in a floating state
    reapply = true,                                   -- Whether all those properties should be reapplied on every new opening of the scratchpad (MUST BE TRUE FOR ANIMATIONS)
    dont_focus_before_close  = false,                 -- When set to true, the scratchpad will be closed by the toggle function regardless of whether its focused or not. When set to false, the toggle function will first bring the scratchpad into focus and only close it on a second call
    awestore = {x = anim_x, y = anim_y}               -- Optional. This is how you can pass in the stores for animations. If you don't want animations, you can ignore this option.
}
```

Once initalized, you can use the object (which in this case is named `term_scratch`) like this:

```lua
term_scratch:toggle()   -- toggles the scratchpads visibility
term_scratch:turn_on()  -- turns the scratchpads visibility on
term_scratch:turn_off() -- turns the scratchpads visibility off
```
