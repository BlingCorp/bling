local beautiful = require("beautiful")

local backend = beautiful.playerctl_backend or "playerctl_lib"

if backend == "playerctl_cli" then
    return require(... .. ".playerctl_cli")
elseif backend == "playerctl_lib" then
    return require(... .. ".playerctl_lib")
end
