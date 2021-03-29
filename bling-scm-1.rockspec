package = "bling"
version = "scm-1"

source = {
   url = "https://github.com/Nooo37/bling",
   branch = "master",
}

description = {
   summary = "Utilities for the AwesomeWM",
   detailed = [[
    This module extends the Awesome window manager with alternative layouts, 
    flash focus, tabbing, a simple tiling wallpaper generator, a declarative 
    wallpaper setter, window swallowing and a playerctl signal.
   ]],
   homepage = "https://github.com/Nooo37/bling",
   license = "MIT",
}

dependencies = {
   "lua >= 5.1",
   "awesome >= 4.0",
}

build = {
   type = "builtin",
   modules = { bling = "init.lua" },
}
