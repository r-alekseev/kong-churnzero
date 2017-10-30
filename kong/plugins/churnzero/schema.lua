return {
  no_consumer = false,
  fields = {
    endpoint_url = { required = true, type = "url" },
    timeout = { default = 10000, type = "number" },
    -- keepalive = { default = 60000, type = "number" },
    app_key = { required = true, type = "string" },
    account_external_id = { required = true, type = "string" },
    contact_external_id = { type = "table",
    required = true,
      schema = {
        fields = {
          from = { required = true, default = "consumer", type = "string", enum = { "consumer", "credential" } },
          unauthenticated = { required = true, default = "disabled", type = "string", enum = { "disabled", "ip" } }
        }
      }
    },
    event_from_response_header = { type = "table",
      required = true,    -- by now, catch response headers is the only way to handle event; alternative is to regex rotes
      schema = {
        fields = {
          header_name = { required = true, default = "X-ChurnZero-Event", type = "string" },
          event_name_quantity_delimiter = { required = true, default = ":", type = "string" },
        }
      }
    },
    -- TODO: implement debug setting and optimized debug function
    -- debug = { required = true, default = true, type = "boolean" }
  },
  self_check = function(schema, plugin_t, dao, is_updating)
    return true
  end
}   
