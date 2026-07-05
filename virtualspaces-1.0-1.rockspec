rockspec_format = "3.0"
package = "VirtualSpaces"
version = "1.0-1"

source = {
   url = "https://github.com/brennovich/VirtualSpaces.spoon/releases/latest/download/VirtualSpaces.spoon.zip"
}

description = {
   summary = "Virtual workspace management for Hammerspoon",
   detailed = [[
      VirtualSpaces provides i3-like virtual workspace functionality for macOS using Hammerspoon.
      It manages window placement across multiple virtual workspaces using macOS Spaces.
   ]],
   homepage = "https://github.com/brennovich/VirtualSpaces.spoon",
   license = "GPL-3.0"
}

dependencies = {
   "lua >= 5.3"
}

test_dependencies = {
   "luaunit >= 3.4"
}

build = {
   type = "none"
}

test = {
   type = "command",
   command = "eval $(luarocks --local path) && lua tests/test.lua -o TAP"
}
