package = "kong-plugin-churnzero-eventtracker"  

version = "0.1.0-1"               

supported_platforms = {"linux", "macosx"}
source = {
  url = "https://github.com/r-alekseev/kong-churnzero",
  tag = "0.1.0"
}

description = {
  summary = "Send request logs to ChurnZero",
  homepage = "https://github.com/r-alekseev/kong-churnzero",
  license = "MIT"
}

dependencies = {
}

local pluginName = "churnzero-eventtracker"  
build = {
  type = "builtin",
  modules = {
    ["kong.plugins."..pluginName..".handler"] = "kong/plugins/"..pluginName.."/handler.lua",
    ["kong.plugins."..pluginName..".schema"] = "kong/plugins/"..pluginName.."/schema.lua",
  }
}
