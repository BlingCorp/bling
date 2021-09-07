local wibox = require("wibox")
local awful = require("awful")
local gears = require("gears")
local beautiful = require("beautiful")
local dpi = require("beautiful.xresources").apply_dpi
local tabbed_module = require(
    tostring(...):match(".*bling") .. ".module.tabbed"
)

-- Just check if a table contains a value.
local function tbl_contains(tbl, item)
    for _, v in ipairs(tbl) do
        if v == item then
            return true
        end
    end
    return false
end

-- Needs to be run, every time a new titlbear is created
return function(c, opts)
    -- Args & Fallback -- Widget templates are in their original loactions
    opts = gears.table.crush({
        layout_spacing = dpi(4),
        icon_size = dpi(20),
        icon_margin = dpi(4),
        bg_color_focus = "#ff0000",
        bg_color = "#00000000",
        icon_shape = function(cr, w, h)
            gears.shape.rounded_rect(cr, w, h, 0)
        end,
    }, gears.table.join(
        opts,
        beautiful.bling_tabbed_misc_titlebar_indicator
    ))

    -- Container to store icons
    local tabbed_icons = wibox.widget({
        layout = wibox.layout.fixed.horizontal,
        spacing = opts.layout_spacing,
    })

    awesome.connect_signal(
        "bling::tabbed::client_removed",
        function(_, removed_c)
            -- Remove from list
            for idx, icon in ipairs(tabbed_icons.children) do
                if
                    icon:get_children_by_id("icon_role")[1].client == removed_c
                then
                    tabbed_icons:remove(idx)
                end
            end

            -- Empty list
            if removed_c == c then
                tabbed_icons:reset()
            end
        end
    )

    local function recreate(group)
        if tbl_contains(group.clients, c) then
            tabbed_icons:reset()
            local focused = group.clients[group.focused_idx]

            -- Autohide?
            if #group.clients == 1 then
                return
            end

            for idx, client in ipairs(group.clients) do
                local widget = wibox.widget(opts.widget_template or {
                    {
                        {
                            {
                                id = "icon_role",
                                forced_width = opts.icon_size,
                                forced_height = opts.icon_size,
                                widget = awful.widget.clienticon,
                            },
                            margins = opts.icon_margin,
                            widget = wibox.container.margin,
                        },
                        bg = (client == focused) and opts.bg_color_focus
                            or opts.bg_color,
                        shape = opts.icon_shape,
                        id = "click_role",
                        widget = wibox.container.background,
                    },
                    halign = "center",
                    valign = "center",
                    widget = wibox.container.place,
                })

                -- Add icons & etc
                for _, w in ipairs(widget:get_children_by_id("icon_role")) do
                    -- TODO: Allow fallback icon?
                    w.image = client.icon
                    w.client = client
                end

                for _, w in ipairs(widget:get_children_by_id("click_role")) do
                    w:add_button(awful.button({}, 1, function()
                        tabbed_module.switch_to(group, idx)
                    end))
                end

                tabbed_icons:add(widget)
            end
        end
    end

    awesome.connect_signal("bling::tabbed::client_added", recreate)
    awesome.connect_signal("bling::tabbed::changed_focus", recreate)

    return tabbed_icons
end
