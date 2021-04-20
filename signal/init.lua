local beautiful = require("beautiful")

if beautiful.playerctl_backend == "cli" then
    return {playerctl = require(... .. ".playerctl_cli")}
else
    return {playerctl = require(... .. ".playerctl_lib")}
end
