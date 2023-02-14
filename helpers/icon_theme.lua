-------------------------------------------
-- @author https://github.com/Kasper24
-- @copyright 2021-2022 Kasper24
-------------------------------------------
local lgi = require("lgi")
local Gio = lgi.Gio
local DesktopAppInfo = Gio.DesktopAppInfo
local Gtk = lgi.require("Gtk", "3.0")

local ICON_SIZE = 48
local GTK_THEME = Gtk.IconTheme.get_default()

local _icon_theme = {}

function _icon_theme.choose_icon(icons_names, icon_theme, icon_size)
    if icon_theme then
        GTK_THEME = Gtk.IconTheme.new()
        Gtk.IconTheme.set_custom_theme(GTK_THEME, icon_theme);
    end
    if icon_size then
        ICON_SIZE = icon_size
    end

    local icon_info = GTK_THEME:choose_icon(icons_names, ICON_SIZE, 0);
    if icon_info then
        local icon_path = icon_info:get_filename()
        if icon_path then
            return icon_path
        end
    end

    return ""
end

function _icon_theme.get_gicon_path(gicon, icon_theme, icon_size)
    if gicon == nil then
        return ""
    end

    if icon_theme then
        GTK_THEME = Gtk.IconTheme.new()
        Gtk.IconTheme.set_custom_theme(GTK_THEME, icon_theme);
    end
    if icon_size then
        ICON_SIZE = icon_size
    end

    local icon_info = GTK_THEME:lookup_by_gicon(gicon, ICON_SIZE, 0);
    if icon_info then
        local icon_path = icon_info:get_filename()
        if icon_path then
            return icon_path
        end
    end

    return ""
end

function _icon_theme.get_icon_path(icon_name, icon_theme, icon_size)
    if icon_theme then
        GTK_THEME = Gtk.IconTheme.new()
        Gtk.IconTheme.set_custom_theme(GTK_THEME, icon_theme);
    end
    if icon_size then
        ICON_SIZE = icon_size
    end

    local icon_info = GTK_THEME:lookup_icon(icon_name, ICON_SIZE, 0)
    if icon_info then
        local icon_path = icon_info:get_filename()
        if icon_path then
            return icon_path
        end
    end

    return ""
end

function _icon_theme.get_client_icon_path(client, icon_theme, icon_size)
    local desktop_app_info_filename = DesktopAppInfo.search(client.class)[1][1]
    if desktop_app_info_filename then
        local desktop_app_info = DesktopAppInfo.new(desktop_app_info_filename)
        if desktop_app_info then
            local icon_name = desktop_app_info:get_string("Icon")
            if icon_name then
                return _icon_theme.get_icon_path(icon_name, icon_theme, icon_size)
            end
        end
    end

    return _icon_theme.choose_icon({"window", "window-manager", "xfwm4-default", "window_list"}, icon_theme, icon_size)
end

return _icon_theme