local plugin = require("kong.plugins.base_plugin"):extend()

function plugin:new()
  plugin.super.new(self, "churnzero")
end

plugin.PRIORITY = 1000

return plugin
