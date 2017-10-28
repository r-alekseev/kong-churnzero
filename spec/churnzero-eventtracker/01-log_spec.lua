local helpers = require "spec.helpers"

describe("Plugin: churnzero-eventtracker (log)", function()
  local client

  setup(function()
    -- start kong, while setting the config item `custom_plugins` to make sure our
    -- plugin gets loaded
    assert(helpers.start_kong {custom_plugins = "churnzero-eventtracker"})
  end)

  teardown(function()
    helpers.stop_kong()
  end)

  before_each(function()
    client = helpers.proxy_client()
  end)

  after_each(function()
    if client then client:close() end
  end)

end)