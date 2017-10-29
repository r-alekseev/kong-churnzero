local utils = require "kong.tools.utils"

return {
  no_consumer = false,
  fields = {
    endpoint_url = { required = true, type = "url" },
    timeout = { default = 10000, type = "number" },
    keepalive = { default = 60000, type = "number" },
    app_key = { required = true, type = "string" },
    account_external_id = { required = true, type = "string" },
    contact_external_id_authenticated_only = { default = true, type = "bool" },
    event_from_response_header_names = { default = "X-ChurnZero-Event", type = "string" },
    event_name_quantity_separator = { default = ":", type = "string" }
  },
  self_check = function(schema, plugin_t, dao, is_updating)
    return true
  end
}
