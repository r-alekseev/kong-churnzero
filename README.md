# Kong ChurnZero Plugin

[![Build Status](https://travis-ci.org/r-alekseev/kong-churnzero.svg?branch=master)](https://travis-ci.org/r-alekseev/kong-churnzero) <br/>

## Table of Contents

- 1. [Usage][usage]
- 2. [Installation][installation]
- 3. [Configuration][configuration]
- 4. [Demonstration][demonstration]

[usage]: #1-usage
[installation]: #2-installation
[configuration]: #3-configuration
[demonstration]: #4-demonstration

## 1. Usage

This plugin enables logging events from Kong to [ChurnZero](https://churnzero.net) (customer success software).

See also [What is ChurnZero](https://churnzero.readme.io/docs/welcome-to-churnzero) and [How to integrate](https://churnzero.readme.io/docs/integrate-churnzero-using-serverbackend-integration-http-api) readme pages.

[Back to TOC](#table-of-contents)

## 2. Installation

To install this plugin (and be able to configure it via the Kong Admin API),
follow the instructions in the provided INSTALL.txt file.

You must do so for every node in your Kong cluster. See the section about using
LuaRocks behind a proxy if necessary, in the INSTALL.txt file.

In short, if you're using `luarocks` execute the following:

     luarocks install kong-churnzero

You also need to set the `KONG_CUSTOM_PLUGINS` environment variable

     export KONG_CUSTOM_PLUGINS=churnzero

or if other plugins already installed 

     export KONG_CUSTOM_PLUGINS=other_plugins,churnzero



[Back to TOC](#table-of-contents)

## 3. Configuration

Method 1: apply it on top of an API by executing the following request on your
Kong server:

```bash
$ curl -X POST http://kong:8001/apis/{api}/plugins \
    --data "name=churnzero" \
    --data "config.endpoint_url=CHURNZERO_ENDPOINT_URL" \
    --data "config.app_key=CHURNZERO_APPLICATION_KEY"
```

Method 2: apply it globally (on all APIs) by executing the following request on
your Kong server:

```bash
$ curl -X POST http://kong:8001/plugins \
    --data "name=churnzero" \
    --data "config.endpoint_url=CHURNZERO_ENDPOINT_URL" \
    --data "config.app_key=CHURNZERO_APPLICATION_KEY"
```

`api`: The `id` or `name` of the API that this plugin configuration will target

Please read the [Plugin Reference](https://getkong.org/docs/latest/admin-api/#add-plugin)
for more information.


**Common settings**

Attribute                                      | Default value  | Description
----------------------------------------------:|---------------:|-------------------------------------------------------
`name`                                         |                | The name of the plugin to use, in this case: `churnzero`
**(required)** `config.endpoint_url`           |                | Endpoint (host) of the ChurnZero server.
**(required)** `config.app_key`                |                | Application key in the ChurnZero system. Ask the ChurnZero team.
`config.timeout`                               | `10000`        | The time for waiting the response of the http-request.
`config.unauthenticated_enabled`               | `true`         | `false` means events from unauthenticated consumers will not be sent to ChurnZero.
`config.events_from_route_patterns`            |                | Kong will send to ChurnZero events based on what pattern is matched with route string. Whitespace separates pattern from event name. F.e. if route string is `/myentity/123` and this property value array is `[ "/myentity/%d+ GetEntity", "/anotherentity/%d+ GetAnotherEntity" ]`, Kong will send `GetEntity` event to ChurnZero because `/myentity/%d+` matched to `/myentity/123`. (see [Lua Patterns](https://www.lua.org/pil/20.2.html))
`config.events_from_header_prefix`             | `X-ChurnZero-` | Kong will send to ChurnZero events based on headers starting with this prefix. F.e. if the header `X-ChurnZero-EventName:SomeMethodCalled` occured in the upstream response, Kong will send `SomeMethodCalled` event to ChurnZero.
`config.hide_churnzero_headers`                | `true`         | `true` means the headers used to produce events will not be sent to a downstream.


**Account settings**

Attribute                                      | Default value  | Description
----------------------------------------------:|---------------:|-------------------------------------------------------
`config.account.authenticated_from`            | `consumer`     | When consumer authenticated, this property value will be used to fill `accountExternalId` event attribute in case of this attribute unspecified. Possible values: `consumer`, `credential`. `consumer` means use consumer `name`, `custom_id` or `id`. `credential` means use credential `key`.
`config.account.unauthenticated_from`          | `ip`           | When consumer unauthenticated, this property value will be used to fill `accountExternalId` event attribute in case of this attribute unspecified. Possible values: `ip`, `constant`. `ip` means use consumer ip address. `constant` means use `config.account.unauthenticated_from_const` property value
`config.account.unauthenticated_from_const`    | `anonymous`    | When consumer unauthenticated and `config.account.unauthenticated_from` property value is `constant`, this property value will be used to fill `accountExternalId` event attribute.
`config.account.prefix`                        |                | The value of this property will be prepend to autogenerated `accountExternalId` event attribute in case of this attribute unspecified.


**Contact sttings**

Attribute                                      | Default value  | Description
----------------------------------------------:|---------------:|-------------------------------------------------------
`config.contact.authenticated_from`            | `consumer`     | When consumer authenticated, this property value will be used to fill `contactExternalId` event attribute in case of this attribute unspecified. Possible values: `consumer`, `credential`. `consumer` means use consumer `name`, `custom_id` or `id`. `credential` means use credential `key`.
`config.contact.unauthenticated_from`          | `ip`           | When consumer unauthenticated, this property value will be used to fill `contactExternalId` event attribute in case of this attribute unspecified. Possible values: `ip`, `constant`. `ip` means use consumer ip address. `constant` means use `config.contact.unauthenticated_from_const` property value
`config.contact.unauthenticated_from_const`    | `anonymous`    | When consumer unauthenticated and `config.contact.unauthenticated_from` property value is `constant`, this property value will be used to fill `contactExternalId` event attribute.
`config.contact.prefix`                        | `contact-`     | The value of this property will be prepend to autogenerated `contactExternalId` event attribute in case of this attribute unspecified.

[Back to TOC](#table-of-contents)

## 4. Demonstration

For this demonstration we are running Kong locally on a
Vagrant machine on a MacOS.

1. Create an API on Kong

    ```bash
    $ curl -i -X  POST http://localhost:8001/apis/ \
      --data "name=test-api" -d "hosts=example.com" \
      --data "upstream_url=http://localhost"

    HTTP/1.1 201 Created
    ...

    ```

2. Apply the `churnzero` plugin to the API on Kong

    ```bash
    $ curl -i -X POST http://localhost:8001/apis/test-api/plugins \
        --data "name=churnzero" \
        --data "config.endpoint_url=https://eu1analytics.churnzero.net/i" \
        --data "config.app_key=A-aa1bb2cc3dd4_eF-jklmnOpq2Rst234-U0v879Wxuz" 

    HTTP/1.1 201 Created
    ...

    ```

3. Make a request to an api. 

      ```bash
      $ curl -i -X POST http://localhost:8000/ -H "Host:example.com"
      HTTP/1.1 200 OK
      ...
      
      ```

4. If the upstream api returns applicable headers (see `config.events_from_header_prefix` setting) or if the requested route matches a pattern (see `config.events_from_route_patterns` setting) then the Kong will send following request to the ChurnZero endpoint:
   
   ```
   POST https://eu1analytics.churnzero.net HTTP/1.1
   Host: /i
   Content-Type: application/json
   Cache-Control: no-cache
   Content-Length: ...
   
   [
    {
      "appKey": "A-aa1bb2cc3dd4_eF-jklmnOpq2Rst234-U0v879Wxuz",
      "action": "trackEvent",
      ...
    }
   ]
   ```
   
### Headers matching

By default, the `config.events_from_header_prefix` property value is `X-ChurnZero-`. This means that the `churnzero` plugin will catch the following headers in each response from the upstream:<br>

`X-ChurnZero-EventName`<br>
`X-ChurnZero-Quantity`<br>
`X-ChurnZero-AccountExternalId`<br>
`X-ChurnZero-ContactExternalId`<br>
`X-ChurnZero-AppKey`<br>
`X-ChurnZero-EventDate`<br>
<br>and/or similar headers with dash+integer postfix `-1`, `-2`, `-n` series without skippings f.e.:<br>

`X-ChurnZero-EventName-1`<br>
`X-ChurnZero-EventName-2`<br>
`X-ChurnZero-Quantity-2`<br>
(`*EventName*` is **required** the rest are **optional**)


**Example 1: Full event from headers:**

Confguration settings:

  ```
  config.events_from_header_prefix = "X-ChurnZero-" (by default)
  ```

Upstream response headers:

  ```
  X-ChurnZero-EventName: GetProductList
  X-ChurnZero-Quantity: 1
  X-ChurnZero-AccountExternalId: pineapple.com
  X-ChurnZero-ContactExternalId: m.kong@pineapple.com
  X-ChurnZero-AppKey: A-aa1bb2cc3dd4_eF-jklmnOpq2Rst234-U0v879Wxuz
  X-ChurnZero-EventDate: 2017-11-14T01:07:35Z
  ```
    
ChurnZero log http request body:

  ```
  [
    {
      "appKey": "A-aa1bb2cc3dd4_eF-jklmnOpq2Rst234-U0v879Wxuz", 
      "accountExternalId": "pineapple",
      "contactExternalId": "m.kong@pineapple.com",
      "action": "trackEvent",
      "eventDate": "2017-11-14T01:07:35Z",
      "eventName": "GetProductList",
      "quantity": 1
    }
  ]
  ```
  
  
**Example 2: Two events (part from headers, the rest from settings):**
    
Upstream response header:

  ```
  X-ChurnZero-EventName-1: GetProductList
  X-ChurnZero-EventName-2: GetSpecialProductList
  X-ChurnZero-Quantity-2: 2
  ```
  
Confguration settings:

  ```
  config.app_key = "A-aa1bb2cc3dd4_eF-jklmnOpq2Rst234-U0v879Wxuz"
  config.account.authenticated_from = "consumer"    (by default) (f.e. consumer is "pineapple")
  config.account.prefix = ""                        (by default)
  config.contact.authenticated_from = "consumer"    (by default) (f.e. consumer is "pineapple")
  config.contact.prefix = "contact-"                (by default)
  config.events_from_header_prefix = "X-ChurnZero-" (by default)
  ```

ChurnZero log http request body:

  ```
  [
    {
      "appKey": "A-aa1bb2cc3dd4_eF-jklmnOpq2Rst234-U0v879Wxuz", 
      "accountExternalId": "pineapple",
      "contactExternalId": "contact-pineapple",
      "action": "trackEvent",
      "eventDate": "2017-11-14T01:07:35Z",      (kong server date)
      "eventName": "GetProductList",            (from header)
      "quantity": 1                             (default)
    },
    {
      "appKey": "A-aa1bb2cc3dd4_eF-jklmnOpq2Rst234-U0v879Wxuz", 
      "accountExternalId": "pineapple",
      "contactExternalId": "contact-pineapple",
      "action": "trackEvent",
      "eventDate": "2017-11-14T01:07:35Z",      (kong server date)
      "eventName": "GetSpecialProductList",     (from header)
      "quantity": 2                             (from header)
    }
  ]
  ```
  
### Route string patterns matching

By default, the `config.events_from_route_patterns` property value is empty. This means route string pattern matching is disabled.

To enable route string pattern matching need to add a pattern <br>
`config.events_from_route_patterns[1]=/entity/%d+ GetEntity` (the space separates a pattern part from an event-name part).
This means that the `churnzero` plugin will send an event with EventName = `GetEntity` to ChurnZero on each request from any consumer in case of `/entity/%d+` matched to the route string.

It is possible to add several patterns: <br>
`config.events_from_route_patterns[2]=/file/%d+ GetFile`


**Example 3: Event name from route string, the rest from settings:**

Route string:

  ```
  /entity/123
  ```

Confguration settings:

  ```
  config.app_key = "A-aa1bb2cc3dd4_eF-jklmnOpq2Rst234-U0v879Wxuz"
  config.account.authenticated_from = "consumer"  (by default) (f.e. consumer is "pineapple")
  config.account.prefix = ""                      (by default)
  config.contact.authenticated_from = "consumer"  (by default) (f.e. consumer is "pineapple")
  config.contact.prefix = "contact-"              (by default)
  config.events_from_route_patterns[1] = "/entity/%d+ GetEntity"
  ```

ChurnZero log http request body:

  ```
  [
    {
      "appKey": "A-aa1bb2cc3dd4_eF-jklmnOpq2Rst234-U0v879Wxuz", 
      "accountExternalId": "pineapple",
      "contactExternalId": "contact-pineapple",
      "action": "trackEvent",
      "eventDate": "2017-11-14T02:11:58Z",
      "eventName": "GetEntity",
      "quantity": 1
    }
  ]
  ```

[Back to TOC](#table-of-contents)
