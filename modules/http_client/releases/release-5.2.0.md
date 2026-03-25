# dream_http_client v5.2.0

**Release Date:** March 25, 2026

This release exposes the 6 previously hardcoded `httpc` configuration values
as user-configurable options. Per-request settings (`connect_timeout`,
`auto_redirect`) are added to the `ClientRequest` builder. Profile-level
transport settings (`max_sessions`, `max_pipeline_length`, `keep_alive_timeout`,
`max_keep_alive_length`) are managed through a new `TransportConfig` type.
All defaults match the previous hardcoded values — existing code behaves
identically without changes.

No breaking changes. Minor version bump (5.1.3 → 5.2.0).

---

## Feature: Per-request connection timeout

`connect_timeout(ms)` controls how long to wait for the TCP connection to be
established. This is separate from `timeout()`, which controls the entire
request/response cycle.

```gleam
client.new()
|> client.host("api.example.com")
|> client.connect_timeout(5000)
|> client.send()
```

**Default:** 15000ms (matches previous hardcoded value).

**Use case:** Fail fast against unreachable hosts without shortening the
overall request timeout. For example, set `connect_timeout(2000)` with
`timeout(60_000)` to detect connection failures quickly while still allowing
slow responses.

Maps directly to Erlang httpc's `{connect_timeout, Ms}` HTTP option.

---

## Feature: Per-request redirect control

`auto_redirect(enabled)` controls whether 3xx redirects are followed
automatically.

```gleam
// Disable auto-redirect to inspect the 3xx response
client.new()
|> client.host("api.example.com")
|> client.path("/old-endpoint")
|> client.auto_redirect(False)
|> client.send()
```

**Default:** `True` (matches previous hardcoded value).

When disabled, the 3xx response is returned as `Ok(HttpResponse(...))` with
the redirect status code and `Location` header visible. Since `response_result`
only returns `Error(ResponseError(...))` for status >= 400, 3xx responses
come through as `Ok` — the correct behavior for manual redirect handling.

Maps directly to Erlang httpc's `{autoredirect, Bool}` HTTP option.

---

## Feature: Global transport configuration

`TransportConfig` is a new opaque type for tuning the httpc connection pool.
These settings are global (applied to the httpc default profile) and affect
all subsequent HTTP requests.

```gleam
client.transport_config()
|> client.max_sessions(200)
|> client.max_pipeline_length(0)
|> client.keep_alive_timeout(120_000)
|> client.max_keep_alive_length(50)
|> client.configure_transport()
```

### Settings

| Builder | Default | What it controls |
|---------|---------|-----------------|
| `max_sessions(count)` | 100 | Concurrent TCP connections per host |
| `max_pipeline_length(length)` | 0 | HTTP pipelining depth (0 = disabled) |
| `keep_alive_timeout(ms)` | 60000 | Idle connection lifetime before close |
| `max_keep_alive_length(count)` | 100 | Max requests per keep-alive connection |

### How it works

`configure_transport()` does two things:

1. Writes the config to a named ETS table (`dream_http_client_transport_config`)
   so it persists across requests
2. Immediately calls `httpc:set_options/2` on the `default` profile

The ETS table is created during OTP application startup (in
`dream_http_client_app:start/2`) alongside the existing ref mapping and
recorder tables. `configure_httpc/0`, which runs before every HTTP request,
reads from this table — if populated, it uses the stored values; otherwise,
it falls back to the hardcoded defaults.

This means:
- Call `configure_transport()` once at startup and all requests use those settings
- Call it again at runtime to update settings without restart
- If never called, behavior is identical to previous versions

### Why ETS, not an actor

Transport config is read on every request by `configure_httpc/0` but written
rarely (typically once at startup). ETS provides concurrent reads without
bottlenecking through a single actor process. This follows the same pattern
used by the existing `dream_http_client_ref_mapping` table.

---

## Propagation chain

The new per-request parameters flow through the full call chain:

```
ClientRequest builder (Gleam)
  → resolve_connect_timeout / resolve_auto_redirect (Gleam, applies defaults)
    → send_sync FFI / start_httpc_stream / start_stream_messages (Gleam → Erlang)
      → request_sync/7 / request_stream/8 / request_stream_messages/8 (Erlang shim)
        → httpc:request/4 HttpOpts [{connect_timeout, Ms}, {autoredirect, Bool}]
```

All three request paths (`send()`, `stream_yielder()`, `start_stream()`)
propagate both parameters. The intermediate types `YielderState` and
`RecordingYielderState` were updated to carry `connect_timeout_ms` and
`auto_redirect` alongside the existing `timeout_ms`.

---

## Test coverage

14 new tests (206 total across the module):

| Category | Count | Coverage |
|----------|-------|----------|
| `connect_timeout` builder/getter | 3 | set value, default None, accepts zero |
| `auto_redirect` builder/getter | 3 | set False, default None, set True |
| `TransportConfig` defaults | 1 | all 4 fields match expected defaults |
| `TransportConfig` builders | 4 | one per field with value verification |
| Builder chaining | 1 | all 4 builders chained, all 4 getters verified |
| `configure_transport` | 1 | applies without error (returns Nil) |
| Edge case: zero values | 1 | `max_sessions(0)` accepted |

3 new test snippets for documentation examples:
- `test/snippets/connect_timeout_config.gleam`
- `test/snippets/redirect_config.gleam`
- `test/snippets/transport_config_example.gleam`

---

## Files changed

- `modules/http_client/src/dream_http_client/client.gleam` — Added
  `connect_timeout` and `auto_redirect` fields to `ClientRequest`, updated
  `new()`, added builder/getter/resolve functions, added `TransportConfig`
  type with factory/builders/getters, added `configure_transport` and its
  FFI declaration
- `modules/http_client/src/dream_http_client/internal.gleam` — Updated
  `request_stream` FFI signature to `/8`, `start_stream_messages` to `/8`,
  `start_httpc_stream` to accept and pass `connect_timeout_ms` and
  `autoredirect`
- `modules/http_client/src/dream_http_client/dream_httpc_shim.erl` — Updated
  `request_sync/5` → `/7`, `request_stream/6` → `/8`,
  `request_stream_messages/6` → `/8`, `stream_owner_loop/4` → `/6`;
  added `configure_transport/4`; updated `configure_httpc/0` to read from ETS
- `modules/http_client/src/dream_http_client/dream_http_client_app.erl` —
  Added `dream_http_client_transport_config` ETS table creation
- `modules/http_client/test/client_test.gleam` — 6 new tests for
  `connect_timeout` and `auto_redirect` builders/getters
- `modules/http_client/test/transport_config_test.gleam` — New file, 8 tests
  for `TransportConfig` builders/getters/apply
- `modules/http_client/test/snippets/connect_timeout_config.gleam` — New snippet
- `modules/http_client/test/snippets/redirect_config.gleam` — New snippet
- `modules/http_client/test/snippets/transport_config_example.gleam` — New snippet
- `modules/http_client/CHANGELOG.md` — 5.2.0 entry
- `modules/http_client/README.md` — Added Configuration section
- `modules/http_client/gleam.toml` — Version bump 5.1.3 → 5.2.0

## Upgrading

Update your dependency:

```toml
[dependencies]
dream_http_client = ">= 5.2.0 and < 6.0.0"
```

Then run:

```bash
gleam deps download
```

No breaking changes. All existing code works without modification. The 6
previously hardcoded httpc values now use the same defaults but can be
overridden via the new builder functions.

## Documentation

- [dream_http_client hexdocs](https://hexdocs.pm/dream_http_client) -- v5.2.0
- [README](https://github.com/TrustBound/dream/tree/main/modules/http_client)
- [CHANGELOG](https://github.com/TrustBound/dream/blob/main/modules/http_client/CHANGELOG.md)

## Community

- [Full Documentation](https://github.com/TrustBound/dream/tree/main/modules/http_client)
- [Discussions](https://github.com/TrustBound/dream/discussions)
- [Report Issues](https://github.com/TrustBound/dream/issues)
- [Contributing Guide](https://github.com/TrustBound/dream/blob/main/CONTRIBUTING.md)

---

**Full Changelog:** [CHANGELOG.md](https://github.com/TrustBound/dream/blob/main/modules/http_client/CHANGELOG.md)
