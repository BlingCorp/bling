local cairo = require("lgi").cairo
local awful = require("awful")
local gobject = require("gears.object")
local gtable = require("gears.table")
local gtimer = require("gears.timer")
local gmatrix = require("gears.matrix")
local gsurface = require("gears.surface")
local wibox = require("wibox")
local beautiful = require("beautiful")
local helpers = require(tostring(...):match(".*bling") .. ".helpers")
local dpi = beautiful.xresources.apply_dpi
local collectgarbage = collectgarbage
local ipairs = ipairs
local pcall = pcall
local type = type
local capi = { tag = tag }

local task_preview  = { mt = {} }

local function _get_widget_geometry(_hierarchy, widget)
    local width, height = _hierarchy:get_size()
    if _hierarchy:get_widget() == widget then
        -- Get the extents of this widget in the device space
        local x, y, w, h = gmatrix.transform_rectangle(
            _hierarchy:get_matrix_to_device(),
            0, 0, width, height)
        return { x = x, y = y, width = w, height = h, hierarchy = _hierarchy }
    end

    for _, child in ipairs(_hierarchy:get_children()) do
        local ret = _get_widget_geometry(child, widget)
        if ret then return ret end
    end
end

local function get_widget_geometry(wibox, widget)
    return _get_widget_geometry(wibox._drawable._widget_hierarchy, widget)
end

function task_preview:show(c, args)
    args = args or {}

    args.coords = args.coords or self.coords
    args.wibox = args.wibox
    args.widget = args.widget
    args.offset = args.offset or {}

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

    if not pcall(function()
        return type(c.content)
    end) then
        return
    end

    local content = nil
    if c.active then
        content = gsurface(c.content)
    elseif c.prev_content then
        content = gsurface(c.prev_content)
    end

    local img = nil
    if content ~= nil then
        local cr = cairo.Context(content)
        local x, y, w, h = cr:clip_extents()
        img = cairo.ImageSurface.create(cairo.Format.ARGB32, w - x, h - y)
        cr = cairo.Context(img)
        cr:set_source_surface(content, 0, 0)
        cr.operator = cairo.Operator.SOURCE
        cr:paint()
    end

    local widget = wibox.widget{
        (self.widget_template or {
            {
                {
                    {
                        {
                            id = "icon_role",
                            resize = true,
                            forced_height = dpi(20),
                            forced_width = dpi(20),
                            widget = wibox.widget.imagebox,
                        },
                        {
                            {
                                id = "name_role",
                                align = "center",
                                widget = wibox.widget.textbox,
                            },
                            left = dpi(4),
                            right = dpi(4),
                            widget = wibox.container.margin,
                        },
                        layout = wibox.layout.align.horizontal,
                    },
                    {
                        {
                            {
                                id = "image_role",
                                resize = true,
                                clip_shape = self.image_shape,
                                widget = wibox.widget.imagebox,
                            },
                            valign = "center",
                            halign = "center",
                            widget = wibox.container.place,
                        },
                        top = self.margin * 0.25,
                        widget = wibox.container.margin,
                    },
                    fill_space = true,
                    layout = wibox.layout.fixed.vertical,
                },
                margins = self.margin,
                widget = wibox.container.margin,
            },
            bg = self.bg,
            shape_border_width = self.border_width,
            shape_border_color = self.border_color,
            shape = self.shape,
            widget = wibox.container.background,
        }),
        width = self.forced_width,
        height = self.forced_height,
        widget = wibox.container.constraint,
    }

    -- TODO: have something like a create callback here?

    for _, w in ipairs(widget:get_children_by_id("image_role")) do
        w.image = img -- TODO: copy it with gsurface.xxx or something
    end

    for _, w in ipairs(widget:get_children_by_id("name_role")) do
        w.text = c.name
    end

    for _, w in ipairs(widget:get_children_by_id("icon_role")) do
        w.image = c.icon -- TODO: detect clienticon
    end

    self._private.widget.widget = widget
    self._private.widget.visible = true
end

function task_preview:hide()
    self._private.widget.visible = false
    self._private.widget.widget = nil
    collectgarbage("collect")
end

function task_preview:toggle(c, args)
    if self._private.widget.visible == true then
        self:hide()
    else
        self:show(c, args)
    end
end

local function new(args)
    args = args or {}

    args.type = args.type or "dropdown_menu"
    args.coords = args.coords or nil
    args.placement = args.placement or nil
    args.forced_width = args.forced_width or dpi(200)
    args.forced_height = args.forced_height or dpi(200)
    args.input_passthrough = args.input_passthrough or false

    args.margin = args.margin or beautiful.task_preview_widget_margin or dpi(0)
    args.shape = args.shape or beautiful.task_preview_widget_shape or nil
    args.bg = args.bg or beautiful.task_preview_widget_bg or "#000000"
    args.border_width = args.border_width or beautiful.task_preview_widget_border_width or nil
    args.border_color = args.border_color or beautiful.task_preview_widget_border_color or "#ffffff"
    args.image_shape = args.image_shape or beautiful.task_preview_image_shape or nil

    local ret = gobject{}
    ret._private = {}

    gtable.crush(ret, task_preview)
    gtable.crush(ret, args)

    ret._private.widget = awful.popup
    {
        type = ret.type,
        visible = false,
        ontop = true,
        placement = ret.placement,
        input_passthrough = ret.input_passthrough,
        bg = "#00000000",
        widget = wibox.container.background, -- A dummy widget to make awful.popup not scream
    }

    capi.tag.connect_signal("property::selected", function(t)
        -- Awesome switches up tags on startup really fast it seems, probably depends on what rules you have set
        -- which can cause the c.content to not show the correct image
        gtimer {
            timeout = 0.1,
            call_now  = false,
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

    -- awesome.connect_signal("bling::task_preview::visibility", function(s, v, c)
    --     if v then
    --         -- Update task preview contents
    --         task_preview_box.widget = draw_widget(
    --             c,
    --             opts.structure,
    --             screen_radius,
    --             widget_bg,
    --             widget_border_color,
    --             widget_border_width,
    --             margin,
    --             widget_width,
    --             widget_height
    --         )
    --     else
    --         task_preview_box.widget = nil
    --         collectgarbage("collect")
    --     end

    --     if not placement_fn then
    --         task_preview_box.x = s.geometry.x + widget_x
    --         task_preview_box.y = s.geometry.y + widget_y
    --     end

    --     task_preview_box.visible = v
    -- end)
end

function task_preview.mt:__call(...)
    return new(...)
end

return setmetatable(task_preview, task_preview.mt)