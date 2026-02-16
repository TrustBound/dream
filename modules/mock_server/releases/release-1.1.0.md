# Dream Mock Server Release 1.1.0: Startup Config for Deterministic Tests

**Release Date:** February 15, 2026

This release adds a config-driven startup mode so test suites can define exact
upstream responses without embedding provider-specific behavior in the mock.

## Why this release exists

Proxy/adaptor tests often need deterministic upstream behavior:

- match a specific path (or path prefix),
- optionally enforce a specific HTTP method,
- and return a known status/body pair.

Before this release, `dream_mock_server` mainly exposed built-in demo/testing
endpoints. That was useful, but not expressive enough for endpoint-specific
proxy assertions where tests must control payload shape and status codes.

## What was added

### New startup API

- `server.start_with_config(port, config)`

Starts the mock using only caller-provided routes. Built-in endpoints are not
used in this mode.

### New config module and types

- `dream_mock_server/config`
  - `PathMatch` (`Exact`, `Prefix`)
  - `MockRoute(path, path_match, method, status, body)`
  - `MockConfigContext(routes)` (internal context for config mode)

### Matching behavior

- Routes are evaluated in list order.
- First matching route wins.
- Match conditions:
  - Path matches (`Exact` or `Prefix`)
  - Method matches (`Some(method)`) or route method is `None`
- No match => `404` with body `"Not found"`.

## Backward compatibility

- `server.start(port)` is unchanged and still serves existing built-in endpoints.
- `start_with_config` is additive and backward-compatible.

## How to use it

```gleam
import dream_mock_server/config.{MockRoute, Prefix}
import dream_mock_server/server
import gleam/option.{None}

let config = [
  MockRoute(
    path: "/v1/chat/completions",
    path_match: Prefix,
    method: None,
    status: 200,
    body: "{\"choices\":[{\"message\":{\"content\":\"\"}}]}",
  ),
]

let assert Ok(handle) = server.start_with_config(3004, config)
// ... run tests against http://127.0.0.1:3004 ...
server.stop(handle)
```

## Test coverage added

Config mode includes dedicated tests for:

- exact and prefix path matching,
- first-match ordering behavior,
- optional vs method-specific routes,
- non-200 statuses and custom bodies,
- no-match 404 behavior,
- start/stop/restart lifecycle behavior.

## Upgrade notes

Update dependency constraints:

```toml
[dependencies]
dream_mock_server = ">= 1.1.0 and < 2.0.0"
```

Then:

```bash
gleam deps download
```

