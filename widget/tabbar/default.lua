local wibox = require("wibox")
local beautiful = require("beautiful")

local dpi = beautiful.xresources.apply_dpi

local function get_colors(is_tab_focused, is_client_inactive)
    -- Selected tab when the client is focused
    if is_tab_focused and not is_client_inactive then
        return {
            border_color = (
                beautiful.tabbar_border_focus or
                beautiful.bg_focus or
                "#000000"
            ),
            background   = (
                beautiful.tabbar_bg_focus or
                beautiful.bg_focus or
                "#000000"
            ),
            foreground = (
                beautiful.tabbar_fg_focus or
                beautiful.fg_focus or
                "#FFFFFF"
            )
        }
    end

    -- Inactive tabs when the client is focused
    if not is_tab_focused and not is_client_inactive then
        return {
            border_color = (
                beautiful.tabbar_border_normal or
                beautiful.tabbar_bg_normal or
                "#FFFFFF"
            ),
            background   = (
                beautiful.tabbar_bg_normal or
                beautiful.bg_normal or
                "#FFFFFF"
            ),
            foreground = (
                beautiful.tabbar_fg_normal or
                beautiful.fg_normal or
                "#000000"
            )
        }
    end

    -- Selected tab when the client isn't focused
    if is_tab_focused and is_client_inactive then
        return {
            border_color = (
                beautiful.tabbar_border_inactive or
                beautiful.tabbar_border_focus or
                beautiful.bg_minimize or
                "#000000"
            ),
            background   = (
                beautiful.tabbar_bg_focus_inactive or
                beautiful.tabbar_bg_focus or
                beautiful.bg_minimize or
                "#000000"
            ),
            foreground = (
                beautiful.tabbar_fg_focus_inactive or
                beautiful.tabbar_fg_focus or
                beautiful.fg_minimize or
                "#FFFFFF"
            )
        }
    end

    -- for any other one (not selected tab when the client isn't focused and whatever)
    return {
        border_color = (
            beautiful.tabbar_border_normal or
            beautiful.border_normal or
            "#FFFFFF"
        ),
        background   = (
            beautiful.tabbar_bg_normal_inactive or
            beautiful.tabbar_bg_normal or
            beautiful.bg_normal or
            "#FFFFFF"
        ),
        foreground   = (
            beautiful.tabbar_fg_normal_inactive or
            beautiful.tabbar_fg_normal or
            beautiful.fg_normal or
            "#000000"
        )
    }
end

local function colorize_text(text, color)
    return "<span foreground='" ..
            color ..
            "'>" ..
            text ..
            "</span>"
end

local function create(c, is_tab_focused, buttons, is_client_inactive)
    local colors = get_colors(is_tab_focused, is_client_inactive)

    return wibox.widget {
        {
            {
                {
                    markup = colorize_text((c.name or c.class or "-"), colors.foreground),
                    align  = "center",
                    valign = "center",
                    widget = wibox.widget.textbox(),
                },
                left   = dpi(beautiful.tabbar_margin or dpi(5)) + 5,
                widget = wibox.container.margin,
            },
            bg = colors.background,
            widget = wibox.container.background,
        },
        buttons = buttons,
        bg = colors.border_color,
        widget = wibox.container.background(),
    }
end

return {
    layout = wibox.layout.flex.horizontal,
    create = create,
    position = (
        beautiful.tabbar_position or
        "top"
    ),
    size = (
        beautiful.tabbar_size or dpi(20)
    ),
    bg_normal = (
        beautiful.tabbar_bg_normal or
        beautiful.bg_normal or
        "#ffffff"
    ),
    bg_focus = (
        beautiful.tabbar_bg_focus or
        beautiful.bg_focus or
        "#000000"
    ),
}
