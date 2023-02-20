## 🎨 App Launcher <!-- {docsify-ignore} -->

A popup application launcher similar to Rofi

![](https://user-images.githubusercontent.com/33443763/140196352-07e444fe-cccd-45ad-93fa-5705f09e516b.png)

_image by [JavaCafe01](https://github.com/JavaCafe01)_

### Usage

To enable:

```lua
local app_launcher = bling.widget.app_launcher()
```

To run the app launcher, call `:toggle()` on the launcher.

```lua
app_launcher:toggle()
```

### Example Implementation:

```lua
local args = {
    apps_per_column = 1,
    sort_alphabetically = false,
    reverse_sort_alphabetically = true,
}
local app_launcher = bling.widget.app_launcher(args)
```

### Available Options:

```lua
local args = {
    favorites = { "firefox", "wezterm" }                              -- Favorites are given priority and are bubbled to top of the list
    search_commands = true                                            -- Search by app name AND commandline command
    skip_names = { "Discord" }                                        -- List of apps to omit from launcher
    skip_commands = { "thunar" }                                      -- List of commandline commands to omit from launcher
    skip_empty_icons = true                                           -- Skip applications without icons
    sort_alphabetically = true                                        -- Sorts applications alphabetically
    reverse_sort_alphabetically = false                               -- Sort in reverse alphabetical order (NOTE: must set `sort_alphabetically = false` to take effect)
    select_before_spawn = true                                        -- When selecting by mouse, click once to select app, click once more to open the app.
    hide_on_left_clicked_outside = true                               -- Hide launcher on left click outside the launcher popup
    hide_on_right_clicked_outside = true                              -- Hide launcher on right click outside the launcher popup
    hide_on_launch = true                                             -- Hide launcher when spawning application
    try_to_keep_index_after_searching = false                         -- After a search, reselect the previously selected app
    reset_on_hide = true                                              -- When you hide the launcher, reset search query
    save_history = true                                               -- Save search history
    wrap_page_scrolling = true                                        -- Allow scrolling to wrap back to beginning/end of launcher list
    wrap_app_scrolling = true                                         -- Set app scrolling

    default_app_icon_name = "standard.svg"                            -- Sets default app icon name for apps without icon names
    default_app_icon_path = "~/icons/"                                -- Sets default app icon path for apps without icon paths
    icon_theme = "application"                                        -- Set icon theme
    icon_size = 24                                                    -- Set icon size

    type = "dock"                                                     -- awful.popup type ("dock", "desktop", "normal"...).  See awesomewm docs for more detail
    show_on_focused_screen = true                                     -- Should the app launcher popup show on currently focused screen
    screen = awful.screen                                             -- Screen you want the launcher popup to open on
    placement = awful.placement.top_left                              -- Where launcher popup should be placed
    bg = "#FFFFFF"                                                    -- Set launcher popup bg color
    border_width = dpi(0)                                             -- Set launcher popup border width of popup
    border_color = "#FFFFFF"                                          -- Set launcher popup border color of popup
    shape = function(cr, width, height)                               -- Set launcher popup shape
      gears.shape.rectangle(cr, width, height)
    end

    prompt_bg_color = "#000000"                                       -- Prompt background color
    prompt_icon_font = "Comic Sans"                                   -- Prompt icon font
    prompt_icon_size = 15                                             -- Prompt icon size
    prompt_icon_color = "#FFFFFF"                                     -- Prompt icon color
    prompt_icon = ""                                                 -- Prompt icon
    prompt_label_font = "Comic Sans"                                  -- Prompt labe font
    prompt_label_size = 15                                            -- Prompt labe font
    prompt_label_color = "#FFFFFF"                                    -- Prompt labe font
    prompt_label = "Search"                                           -- Prompt labe font
    prompt_text_font =  "Comic Sans"                                  -- Prompt text font
    prompt_text_size = 15                                             -- Prompt text font
    prompt_text_color = "#FFFFFF"                                     -- Prompt text font

    apps_per_row = 3                                                  -- Set how many apps should appear in each row
    apps_per_column = 3                                               -- Set how many apps should appear in each column

    app_normal_color = "#000000"                                      -- App normal color
    app_selected_color = "#FFFFFF"                                    -- App selected color
    app_name_normal_color = "#FFFFFF"                                 -- App name normal color
    app_name_selected_color = "#000000"                               -- App name selected color
}
```
