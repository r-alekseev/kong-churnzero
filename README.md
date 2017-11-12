# Kong ChurnZero Plugin
## Integrate Kong with ChurnZero using HTTP API

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

This plugin enables logging events from Kong to ChurnZero (customer success software).

What is ChurnZero: https://churnzero.readme.io/docs/welcome-to-churnzero

How to integrate: https://churnzero.readme.io/docs/integrate-churnzero-using-serverbackend-integration-http-api

[Back to TOC](#table-of-contents)

## 2. Installation

To install this plugin (and be able to configure it via the Kong Admin API),
follow the instructions in the provided INSTALL.txt file.

You must do so for every node in your Kong cluster. See the section about using
LuaRocks behind a proxy if necessary, in the INSTALL.txt file.

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

Attribute                                | Description
----------------------------------------:| -----------
`name`                                   | The name of the plugin to use, in this case: `churnzero`
`config.endpoint_url`                    | Endpoint (host) of the ChurnZero server.
`config.app_key`                         | Application key in the Churnzero system. Ask the ChurnZero team.

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

2. Apply the `openwhisk` plugin to the API on Kong

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

4. If the upstream api returns applicable headers (see `conf.events_from_header_prefix` setting) or if the requested route matches a pattern (see `conf.events_from_route_patterns` setting) then the Kong will send following request to the ChurnZero endpoint:
   
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

[Back to TOC](#table-of-contents)
