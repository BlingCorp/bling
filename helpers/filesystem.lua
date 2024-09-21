local lgi = require("lgi")
local Gio = lgi.require("Gio", "2.0")
local GLib = lgi.require("GLib", "2.0")
local awful = require("awful")
local gears = require("gears")

local _filesystem = {}

--- Get a list of files from a given directory.
-- @string path The directory to search.
-- @tparam[opt] table exts Specific extensions to limit the search to. eg:`{ "jpg", "png" }`
--   If ommited, all files are considered.
-- @bool[opt=false] recursive List files from subdirectories
-- @staticfct bling.helpers.filesystem.get_random_file_from_dir
function _filesystem.list_directory_files(path, exts, recursive)
    recursive = recursive or false
    local files, valid_exts = {}, {}

    -- Transforms { "jpg", ... } into { [jpg] = #, ... }
    if exts then
        for i, j in ipairs(exts) do
            valid_exts[j:lower()] = i
        end
    end

    -- Build a table of files from the path with the required extensions
    local file_list =
        Gio.File.new_for_path(path):enumerate_children("standard::*", 0)
    if file_list then
        for file in
            function()
                return file_list:next_file()
            end
        do
            local file_type = file:get_file_type()
            if file_type == "REGULAR" then
                local file_name = file:get_display_name()
                if
                    not exts
                    or valid_exts[file_name:lower():match(".+%.(.*)$") or ""]
                then
                    table.insert(files, file_name)
                end
            elseif recursive and file_type == "DIRECTORY" then
                local file_name = file:get_display_name()
                files = gears.table.join(
                    files,
                    _filesystem.list_directory_files(file_name, exts, recursive)
                )
            end
        end
    end

    return files
end

function _filesystem.save_image_async_curl(url, filepath, callback)
    awful.spawn.with_line_callback(
        string.format("curl -L -s %s -o %s", url, filepath),
        {
            exit = callback,
        }
    )
end

---@param filepath string | Gio.File
---@param callback fun(content: string)
---@return nil
function _filesystem.read_file_async(filepath, callback)
    if type(filepath) == "string" then
        return _filesystem.read_file_async(
            Gio.File.new_for_path(filepath),
            callback
        )
    elseif type(filepath) == "userdata" then
        filepath:load_contents_async(nil, function(_, task)
            local _, content, _ = filepath:load_contents_finish(task)
            return callback(content)
        end)
    end
end

---@param filepath string | Gio.File
---@return string?
function _filesystem.read_file_sync(filepath)
    if type(filepath) == "string" then
        return _filesystem.read_file_sync(Gio.File.new_for_path(filepath))
    elseif type(filepath) == "userdata" then
        local _, content, _ = filepath:load_contents()
        return content
    end
end

---@param str string
local function tobytes(str)
    local bytes = {}

    for i = 1, #str do
        table.insert(bytes, string.byte(str, i))
    end

    return bytes
end

---@param filepath string | Gio.File
---@param content string | string[] | GLib.Bytes
---@param callback? fun(file: Gio.File | userdata | nil): nil
function _filesystem.write_file_async(filepath, content, callback)
    if type(filepath) == "string" then
        return _filesystem.write_file_async(
            Gio.File.new_for_path(filepath),
            content,
            callback
        )
    elseif type(content) == "string" then
        return _filesystem.write_file_async(
            filepath,
            GLib.Bytes.new(tobytes(content)),
            callback
        )
    elseif type(content) == "table" then
        return _filesystem.write_file(
            filepath,
            table.concat(content, "\n"),
            callback
        )
    elseif type(filepath) == "userdata" and type(content) == "userdata" then
        callback = callback or function() end

        return filepath:replace_contents_bytes_async(
            content,
            nil,
            false,
            Gio.FileCreateFlags.REPLACE_DESTINATION,
            nil,
            function(_, task)
                filepath:replace_contents_finish(task)
                return callback(filepath)
            end
        )
    end
end

function _filesystem.file_exists(filepath)
    if filepath then
        return GLib.file_test(filepath, GLib.FileTest.EXISTS)
    else
        return false
    end
end

function _filesystem.dir_exists(filepath)
    if filepath then
        return GLib.file_test(filepath, GLib.FileTest.IS_DIR)
    else
        return false
    end
end

return _filesystem
