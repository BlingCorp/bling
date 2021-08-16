## 🧱 Tabbed Miscellaneous <!-- {docsify-ignore} -->

This comprises a few widgets to better represent tabbed groups (from the tabbed module) in your desktop.
The widgets currently included are:
- Titlebar Indicator
- Tasklist


<!-- TODO: Take a screenshot -->

## Titlebar Indicator

### Usage

To use the task list indicator:
**NOTE:** Options can be set as theme vars under the table `theme.bling_tabbed_misc_titlebar_indicator` 

```lua
bling.widget.tabbed_misc.titlebar_indicator(client, {
	layout_spacing = dpi(5), -- Set spacing in between items
	icon_size = dpi(24),
	icon_margin = 0,
	bg_color_focus = "#282828", -- Color for the focused items
	bg_color = "#1d2021", -- Color for normal / unfocused items
	icon_shape = gears.shape.circle -- Set icon shape,
})
```

a widget_template option is also available:
```lua
bling.widget.tabbed_misc.titlebar_indicator(client, {
	widget_template = {
		{
			widget = awful.widget.clienticon,
			id = 'icon_role'
		},
		widget = wibox.container.margin,
		margins = 2,
		id = 'click_role'
	}
})
```

### Example Implementation

You normally embed the widget in your titlebar...
```lua
awful.titlebar(c).widget = {
		{ -- Left
			bling.widget.tabbed_misc.titlebar_indicator(c),
			layout	= wibox.layout.fixed.horizontal
		},
		{ -- Middle
			{ -- Title
				align  = "center",
				widget = awful.titlebar.widget.titlewidget(c)
			},
			buttons = buttons,
			layout	= wibox.layout.flex.horizontal
		},
		{ -- Right
			awful.titlebar.widget.maximizedbutton(c),
			awful.titlebar.widget.closebutton	 (c),
			layout = wibox.layout.fixed.horizontal
		},
		layout = wibox.layout.align.horizontal
	}
```

## Tasklist

### Usage
Similar to the titlebar indicator, it can be used like so:
**NOTE:** Similar to above, options can also be used under as theme vars under the table 

```lua
require('bling.widget.tabbed').custom_tasklist(s, {
	icon_margin = dpi(0), -- Item Margin
	icon_size = dpi(24), -- Does not apply to tabbed groups
	group_row_spacing = dpi(2), -- Spacing between rows in a group indicator
	filter = awful.widget.tasklist.filter.currenttags, -- Set awful.widget.titlbar like filter
	layout = wibox.layout.fixed.vertical, -- Tasklist layout
	-- widget_template = {...} -- Identical to above widget template, used for regular clients, has click & icon roles
})
```

### Implementation
It can be used as follows:
```lua
s.mywibox:setup {
        layout = wibox.layout.align.horizontal,
        { -- Left widgets
            layout = wibox.layout.fixed.horizontal,
            mylauncher,
            s.mytaglist,
            s.mypromptbox,
        },
        require('bling.widget.tabbed_misc').custom_tasklist(s),
		{ -- Right widgets
            layout = wibox.layout.fixed.horizontal,
            mykeyboardlayout,
            wibox.widget.systray(),
            mytextclock,
            s.mylayoutbox,
        },
    }
```
