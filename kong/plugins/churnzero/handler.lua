local ChurnZeroHandler = require("kong.plugins.base_plugin"):extend()

function ChurnZeroHandler:new()
  ChurnZeroHandler.super.new(self, "churnzero")
end

function ChurnZeroHandler:header_filter(conf)
  ChurnZeroHandler.super.header_filter(self)
end

function ChurnZeroHandler:log(conf)
  ChurnZeroHandler.super.log(self)
end

ChurnZeroHandler.PRIORITY = 802
ChurnZeroHandler.VERSION = "0.1.0"

return ChurnZeroHandler
