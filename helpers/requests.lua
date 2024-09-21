local lgi = require("lgi")
local Soup = lgi.require("Soup", "3.0")
local Gio = lgi.require("Gio", "2.0")
local GLib = lgi.require("GLib", "2.0")
local bit = require("bit")

local gears = require("gears")

---@class Response
---@field url string
---@field status_code number
---@field ok boolean
---@field reason_phrase string
---@field stream userdata
---@field text string
---@field bytes GLib.Bytes
local Response = {}

-- ---@return table
-- Response.json = function(self)
--     local json = require("lib.json")
--     return json.decode(self.text)
-- end

function Response.new(url, status_code, ok, reason_phrase, input_stream)
    local self = setmetatable({}, Response)
    self.url = url
    self.status_code = status_code
    self.ok = ok
    self.reason_phrase = reason_phrase
    self.stream = input_stream
    self.text = ""
    self.bytes = nil

    return self
end

---@param params table<string, any>
---@param parent_key string | nil
---@return string
local function encode_query_params(params, parent_key)
    local encoded_params = {}
    local encoded_val, encoded_key

    for key, value in pairs(params) do
        local full_key = parent_key and (parent_key .. "[" .. key .. "]") or key
        encoded_key = GLib.Uri.escape_string(tostring(full_key), nil, true)

        if type(value) == "table" then
            table.insert(encoded_params, encode_query_params(value, full_key))
        else
            encoded_val = GLib.Uri.escape_string(tostring(value), nil, true)
            table.insert(encoded_params, encoded_key .. "=" .. encoded_val)
        end
    end
    return table.concat(encoded_params, "&")
end

---@class request
local requests = {}

---@alias request_args string | { url: string, params: table<string, any>, headers: table<string, string>, body: GLib.Bytes | string}

---@param method "GET" | "POST" | "PUT" | "DELETE" | "PATCH"
---@param args request_args
---@param callback fun(response: Response): nil
---@return nil
function requests.request(method, args, callback)
    if type(args) == "string" then
        args = gears.table.crush(
            { url = "", params = {} },
            { url = args },
            false
        )
    else
        args = gears.table.crush({ url = "", params = {} }, args, false)
    end

    local session, message, status_code, input_stream, ok, r, output_stream

    session = Soup.Session.new()

    if args.params then
        args.url =
            string.format("%s?%s", args.url, encode_query_params(args.params))
    end

    message = Soup.Message.new_from_uri(
        method,
        GLib.Uri.parse(args.url, GLib.UriFlags.NONE)
    )

    if args.headers then
        for header_name, header_value in pairs(args.headers) do
            message:get_request_headers():append(header_name, header_value)
        end
    end

    if type(args.body) == "string" then
        message.set_request_body_from_bytes(
            nil,
            GLib.Bytes.new({
                string.byte(args.body, 1, #args.body),
            })
        )
    end

    return session:send_async(
        message,
        GLib.PRIORITY_DEFAULT,
        nil,
        function(_, task)
            input_stream = session:send_finish(task)
            status_code = message.status_code
            ok = status_code >= 200 and status_code < 300

            r = Response.new(
                message.uri:to_string(),
                status_code,
                ok,
                message.reason_phrase,
                input_stream
            )
            output_stream = Gio.MemoryOutputStream.new_resizable()

            return output_stream:splice_async(
                r.stream,
                bit.bor(
                    Gio.OutputStreamSpliceFlags.CLOSE_SOURCE,
                    Gio.OutputStreamSpliceFlags.CLOSE_TARGET
                ),
                GLib.PRIORITY_DEFAULT,
                nil,
                function(_, t)
                    output_stream:splice_finish(t)
                    r.bytes = output_stream:steal_as_bytes()
                    r.text = r.bytes:get_data()
                    output_stream:flush_async(GLib.PRIORITY_DEFAULT, nil)
                    return callback(r)
                end
            )
        end
    )
end

---@param args request_args
---@param callback fun(response:Response): nil
---@return nil
function requests.get(args, callback)
    return requests.request("GET", args, callback)
end

---@param args request_args
---@param callback fun(response:Response): nil
---@return nil
function requests.post(args, callback)
    return requests.request("POST", args, callback)
end

---@param args request_args
---@param callback fun(response:Response): nil
---@return nil
function requests.put(args, callback)
    return requests.request("PUT", args, callback)
end

---@param args request_args
---@param callback fun(response:Response): nil
---@return nil
function requests.delete(args, callback)
    return requests.request("DELETE", args, callback)
end

return requests
