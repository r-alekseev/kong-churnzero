local Errors = require "kong.dao.errors"

local conf = {
  no_consumer = false,
  fields = {
    endpoint_url = { required = true, type = "url" },
    timeout = { default = 10000, type = "number" },
    app_key = { required = true, type = "string" },
    account = { type = "table",
      required = true,
      schema = {
        fields = {
          authenticated_from = { required = true, default = "consumer", type = "string", enum = { "consumer", "credential" } },
          unauthenticated_from = { required = true, default = "ip", type = "string", enum = { "ip", "const" } },
          unauthenticated_from_const = { required = false, default = "anonymous", type = "string" },
          prefix = { required = false, default = "", type = "string" },
        }
      }
    },
    contact = { type = "table",
      required = true,
      schema = {
        fields = {
          authenticated_from = { required = true, default = "consumer", type = "string", enum = { "consumer", "credential" } },
          unauthenticated_from = { required = true, default = "ip", type = "string", enum = { "ip", "const" } },
          unauthenticated_from_const = { required = false, default = "anonymous", type = "string" },
          prefix = { required = false, default = "contact-", type = "string" },
        }
      }
    },
    unauthenticated_enabled = { type = "boolean", required = true, default = true },
    events_from_header_prefix = { type = "string", required = true, default = "X-ChurnZero-" },
    events_from_route_patterns = { type = "string", required = false },
    timezone = { type = "string", required = true, default = "Z" },
    hide_churnzero_headers = { type = "boolean", required = true, default = true },
  },
  self_check = function(schema, plugin_t, dao, is_updating)
    if plugin_t.account.unauthenticated_from == "const" and not plugin_t.account.unauthenticated_const then
      return false, Errors.schema "you must set 'account.unauthenticated_const' if 'account.unauthenticated_from' is set to 'const'"
    end

    if plugin_t.contact.unauthenticated_from == "const" and not plugin_t.contact.unauthenticated_const then
      return false, Errors.schema "you must set 'contact.unauthenticated_const' if 'contact.unauthenticated_from' is set to 'const'"
    end

    return true
  end
}

return conf