local cairo = require("lgi").cairo
local awful = require("awful")
local wibox = require("wibox")
local helpers = require(tostring(...):match(".*bling") .. ".helpers")
local gobject = require("gears.object")
local gtable = require("gears.table")
local gtimer = require("gears.timer")
local gmatrix = require("gears.matrix")
local gsurface = require("gears.surface")
local beautiful = require("beautiful")
local dpi = beautiful.xresources.apply_dpi
local collectgarbage = collectgarbage
local ipairs = ipairs
local pcall = pcall
local capi = {client = client, tag = tag}

local tag_preview = {mt = {}}

local function _get_widget_geometry(_hierarchy, widget)
    local width, height = _hierarchy:get_size()
    if _hierarchy:get_widget() == widget then
        -- Get the extents of this widget in the device space
        local x, y, w, h = gmatrix.transform_rectangle(
                               _hierarchy:get_matrix_to_device(), 0, 0, width,
                               height)
        return {x = x, y = y, width = w, height = h, hierarchy = _hierarchy}
    end

    for _, child in ipairs(_hierarchy:get_children()) do
        local ret = _get_widget_geometry(child, widget)
        if ret then return ret end
    end
end

local function get_widget_geometry(wibox, widget)
    return _get_widget_geometry(wibox._drawable._widget_hierarchy, widget)
end

function tag_preview:update(args2)
    local args = self
    local t = args2.t
    local scale2 = args2.scale

    if not args.scale then args.scale = scale2 or 0.2 end

    if not args.coords and args.wibox and args.widget then
        args.coords = get_widget_geometry(args.wibox, args.widget)
        if args.offset.x ~= nil then
            args.coords.x = args.coords.x + args.offset.x
        end
        if args.offset.y ~= nil then
            args.coords.y = args.coords.y + args.offset.y
        end

        self._private.widget.x = args.coords.x
        self._private.widget.y = args.coords.y
    end

    local geo = t.screen:get_bounding_geometry({
        honor_padding = args.padding,
        honor_workarea = args.work_area
    })

    self._private.widget.maximum_width =
        args.scale * geo.width + args.margin * 2
    self._private.widget.maximum_height =
        args.scale * geo.height + args.margin * 2

    local client_list = wibox.layout.manual()
    client_list.forced_height = geo.height
    client_list.forced_width = geo.widget

    for _, c in ipairs(t:clients()) do
        if not c.hidden and not c.minimized then
            local img_box = wibox.widget {
                resize = true,
                forced_height = 100 * args.scale,
                forced_width = 100 * args.scale,
                widget = wibox.widget.imagebox
            }

            -- If fails to set image, fallback to a awesome icon

            if args.client_icon then
                if not pcall(function()
                    img_box.image = gsurface.load(c.icon)
                end) then
                    img_box.image = beautiful.theme_assets.awesome_icon(24,
                                                                        "#222222",
                                                                        "#fafafa")
                end
            end

            if args.tag_preview_image then
                if c.prev_content or t.selected then
                    local content = nil
                    if t.selected then
                        content = gsurface(c.content)
                    else
                        content = gsurface(c.prev_content)
                    end
                    local cr = cairo.Context(content)
                    local x, y, w, h = cr:clip_extents()
                    local img = cairo.ImageSurface.create(cairo.Format.ARGB32,
                                                          w - x, h - y)
                    cr = cairo.Context(img)
                    cr:set_source_surface(content, 0, 0)
                    cr.operator = cairo.Operator.SOURCE
                    cr:paint()

                    img_box = wibox.widget({
                        image = gsurface.load(img),
                        resize = true,
                        opacity = args.client_opacity,
                        forced_height = c.height * args.scale,
                        forced_width = c.width * args.scale,
                        widget = wibox.widget.imagebox
                    })

                end
            end

            local c_bg = args.client_bg

            if c == capi.client.focus then c_bg = beautiful.xcolor4 end

            local client_box = wibox.widget({
                {
                    nil,
                    {
                        nil,
                        img_box,
                        nil,
                        expand = "outside",
                        layout = wibox.layout.align.horizontal
                    },
                    nil,
                    expand = "outside",
                    widget = wibox.layout.align.vertical
                },
                forced_height = math.floor(c.height * args.scale),
                forced_width = math.floor(c.width * args.scale),
                bg = c_bg,
                shape_border_color = args.client_border_color,
                shape_border_width = args.client_border_width,
                shape = helpers.shape.rrect(args.client_border_radius),
                widget = wibox.container.background
            })

            client_box.point = {
                x = math.floor((c.x - geo.x) * args.scale),
                y = math.floor((c.y - geo.y) * args.scale)
            }

            client_list:add(client_box)

        end
    end

    local w = wibox.widget {
        {
            args.background_image,
            {
                {
                    client_list,
                    forced_height = geo.height,
                    forced_width = geo.width,
                    valign = "center",
                    halign = "center",
                    widget = wibox.container.place
                },
                margins = args.tag_margin,
                widget = wibox.container.margin
            },
            layout = wibox.layout.stack
        },
        bg = args.tag_bg,
        shape_border_color = args.tag_border_color,
        shape_border_width = args.tag_border_width,
        shape = helpers.shape.rrect(args.tag_border_radius),
        widget = wibox.container.background
    }

    self._private.widget.widget = w
end

local function new(args)
    args = args or {}

    args.type = args.type or "dropdown_menu"
    args.coords = args.coords or nil
    args.placement = args.placement or nil
    args.wibox = args.wibox
    args.widget = args.widget
    args.offset = args.offset or {}
    args.padding = args.padding
    args.work_area = args.work_area
    args.scale = args.scale
    args.margin = args.margin or dpi(0)
    args.client_icon = args.client_icon
    args.client_opacity = args.client_opacity or 0
    args.client_bg = args.client_bg or "#000000"
    args.client_border_color = args.client_border_color or "#ffffff"
    args.client_border_width = args.client_border_width or dpi(1)
    args.client_border_radius = args.client_border_radius or dpi(0)
    args.tag_margin = args.tag_margin or dpi(0)
    args.tag_bg = args.tag_bg or "#000000"
    args.tag_border_color = args.tag_border_color or "#ffffff"
    args.tag_border_width = args.tag_border_width or dpi(0)
    args.tag_border_radius = args.tag_border_radius or dpi(0)
    args.background_image = args.background_image or nil
    args.tag_preview_image = args.tag_preview_image

    local ret = gobject {}
    ret._private = {}

    gtable.crush(ret, tag_preview)
    gtable.crush(ret, args)

    ret._private.widget = awful.popup({
        type = ret.type,
        visible = false,
        ontop = true,
        placement = ret.placement,
        input_passthrough = ret.input_passthrough,
        bg = "#00000000",
        widget = wibox.container.background -- A dummy widget to make awful.popup not scream
    })

    capi.tag.connect_signal("property::selected", function(t)
        -- Awesome switches up tags on startup really fast it seems, probably depends on what rules you have set
        -- which can cause the c.content to not show the correct image
        gtimer {
            timeout = 0.1,
            call_now = false,
            autostart = true,
            single_shot = true,
            callback = function()
                if t.selected == true then
                    for _, c in ipairs(t:clients()) do
                        c.prev_content = gsurface.duplicate_surface(c.content)
                    end
                end
            end
        }
    end)

    return ret
end

function tag_preview:get_widget() return self._private.widget.widget end

function tag_preview:show(t)
    self:update(t)
    self._private.widget.visible = true
end

function tag_preview:hide()
    self._private.widget.visible = false
    self._private.widget.widget = nil
    collectgarbage("collect")
end

function tag_preview:toggle(t)
    if self._private.widget.visible == true then
        self:hide()
    else
        self:show(t)
    end
end

function tag_preview.mt:__call(...) return new(...) end

return setmetatable(tag_preview, tag_preview.mt)
