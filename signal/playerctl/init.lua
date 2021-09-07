local beautiful = require("beautiful")

-- Use CLI backend as default as it is supported on most if not all systems
local backend_config = beautiful.playerctl_backend or "playerctl_cli"
local backends = {
    playerctl_cli = require(... .. ".playerctl_cli"),
    playerctl_lib = require(... .. ".playerctl_lib"),
}

local function enable_wrapper(args)
    backend_config = (args and args.backend) or backend_config
    backends[backend_config].enable(args)
end

local function disable_wrapper()
    backends[backend_config].disable()
end

return { enable = enable_wrapper, disable = disable_wrapper }
