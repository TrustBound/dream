# dream_http_client v5.2.0

**Release Date:** March 25, 2026

This release replaces the underlying HTTP backend from Erlang's `httpc` to
[gun](https://github.com/ninenines/gun), enabling native HTTP/2 multiplexing
for high-concurrency workloads. Per-request settings (`connect_timeout`,
`auto_redirect`, `protocols`) are added to the `ClientRequest` builder.
`protocols()` enables h2c (HTTP/2 over cleartext) and per-request protocol
preference. Connection pool settings are managed through a redesigned
`TransportConfig` type with 13 gun-native fields plus `log_level` for
controlling log verbosity. All defaults are production-reasonable — existing
code behaves identically without changes.

**Breaking changes** to error types (see Structured Error Types below).
Minor version bump (5.1.3 → 5.2.0) since the version has not been published.

---

## Structured Error Types

All string-based error representations have been replaced with structured Gleam
types that preserve the full detail gun provides.

### Motivation

String errors (`"econnrefused"`, `"timeout"`, `"HTTP 500 Internal Server Error: ..."`)
hide production issues. Consumers cannot reliably pattern-match on error categories
for retry logic, alerting, or circuit breakers without fragile string parsing.

### New types

**`TransportError`** — 8 variants preserving all gun error details:

```gleam
pub type TransportError {
  StreamReset(code: String, description: String)
  Goaway(code: String, last_stream_id: Int, debug_data: String)
  ConnectionError(code: String, description: String)
  RemoteClosed
  TimedOut(timeout_ms: Int)
  ProcessDown(reason: String)
  ConnectFailed(reason: String)
  Unexpected(raw: String)
}
```

**`StreamFailure`** — distinguishes HTTP failures from transport errors:

```gleam
pub type StreamFailure {
  HttpFailure(response: HttpResponse)
  TransportFailure(error: TransportError)
}
```

### Breaking changes

| Before | After |
|--------|-------|
| `RequestError(message: String)` | `RequestError(error: TransportError)` |
| `StreamError(request_id, reason: String)` | `StreamError(request_id, error: StreamFailure)` |
| `on_stream_error(fn(String) -> Nil)` | `on_stream_error(fn(StreamFailure) -> Nil)` |
| `stream_yielder() -> Yielder(Result(BytesTree, String))` | `stream_yielder() -> Yielder(Result(BytesTree, StreamFailure))` |

### Migration guide

**Quick migration** — use the helper functions for the old string behavior:

```gleam
// Before:
Error(client.RequestError(message: msg)) ->
  io.println("Failed: " <> msg)

// After:
Error(client.RequestError(error: err)) ->
  io.println("Failed: " <> client.transport_error_to_string(err))
```

**Recommended** — pattern match on error variants for structured handling:

```gleam
Error(client.RequestError(error: err)) ->
  case err {
    client.ConnectFailed(reason: reason) ->
      io.println("Cannot connect: " <> reason)
    client.TimedOut(timeout_ms: ms) ->
      io.println("Timed out after " <> int.to_string(ms) <> "ms")
    _ ->
      io.println(client.transport_error_to_string(err))
  }
```

**Streaming errors** — distinguish HTTP failures from transport errors:

```gleam
|> client.on_stream_error(fn(failure) {
  case failure {
    client.HttpFailure(response: resp) ->
      io.println("HTTP " <> int.to_string(resp.status) <> ": " <> resp.body)
    client.TransportFailure(error: err) ->
      io.println(client.transport_error_to_string(err))
  }
})
```

---

## Backend change: httpc → gun

The HTTP client backend has been replaced from Erlang's `httpc` to
[gun](https://github.com/ninenines/gun). This brings:

- **HTTP/2 support** — native multiplexing over a single TCP connection
  when connecting to HTTP/2-capable servers (e.g., OpenAI, Anthropic)
- **Connection pooling** — managed by a new `dream_http_conn_manager`
  gen_server with per-host multi-connection pools, round-robin selection,
  and automatic dead-connection cleanup
- **Stale connection retry** — requests that hit a server-closed connection
  are automatically retried once on a fresh connection
- **Protocol negotiation** — TLS connections negotiate HTTP/2 via ALPN,
  falling back to HTTP/1.1; plain TCP uses HTTP/1.1

All public API contracts are preserved. `send()`, `stream_yielder()`, and
`start_stream()` behave identically from the caller's perspective.

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

**Default:** 15000ms.

**Use case:** Fail fast against unreachable hosts without shortening the
overall request timeout.

---

## Feature: Per-request redirect control

`auto_redirect(enabled)` controls whether 3xx redirects are followed
automatically.

```gleam
client.new()
|> client.host("api.example.com")
|> client.path("/old-endpoint")
|> client.auto_redirect(False)
|> client.send()
```

**Default:** `True`.

When disabled, the 3xx response is returned as `Ok(HttpResponse(...))` with
the redirect status code and `Location` header visible. gun does not handle
redirects natively; the shim implements manual redirect following (up to 5
hops).

---

## Feature: Global transport configuration

`TransportConfig` is redesigned with 13 gun-native fields for full
connection pool control.

```gleam
client.transport_config()
|> client.max_connections(200)
|> client.idle_timeout(120_000)
|> client.max_concurrent_streams(500)
|> client.configure_transport()
```

### Settings

| Builder | Default | What it controls |
|---------|---------|-----------------|
| `max_connections(count)` | 50 | TCP connections per host |
| `idle_timeout(ms)` | 60000 | Idle connection lifetime before close |
| `default_connect_timeout(ms)` | 15000 | TCP connect timeout |
| `domain_lookup_timeout(ms)` | 5000 | DNS resolution timeout |
| `tls_handshake_timeout(ms)` | 10000 | TLS negotiation timeout |
| `retry(count)` | 3 | Connection retry attempts |
| `retry_timeout(ms)` | 1000 | Delay between retries |
| `keepalive(ms)` | 30000 | HTTP/2 PING interval |
| `keepalive_tolerance(count)` | 3 | Missed PINGs before close |
| `max_concurrent_streams(count)` | 100 | HTTP/2 streams per connection |
| `initial_connection_window_size(bytes)` | 65535 | HTTP/2 connection flow control |
| `initial_stream_window_size(bytes)` | 65535 | HTTP/2 stream flow control |
| `closing_timeout(ms)` | 15000 | Graceful shutdown timeout |

### How it works

`configure_transport()` writes the config to a named ETS table
(`dream_http_client_transport_config`). The shim reads from this table
before every connection, falling back to defaults if no config is stored.

The connection pool is managed by `dream_http_conn_manager`, a gen_server
supervised by `dream_http_client_sup`. It uses an ETS `bag` table
(`dream_http_client_connections`) for per-host multi-connection pooling with:

- Round-robin connection selection
- Proactive dead-connection cleanup
- Idle connection reaping
- Crash recovery (re-monitors connections on gen_server restart)

---

## Feature: Per-request protocol preference

Gun supports HTTP/2 over cleartext (h2c) but the connection manager previously
hardcoded HTTP/1.1 for all TCP connections. The new `protocols()` builder on
`ClientRequest` makes protocol preference configurable per-request.

### Usage

```gleam
import dream_http_client/client.{Http2Only}
import gleam/http

// h2c: HTTP/2 over cleartext using "prior knowledge" mode (RFC 7540 Section 3.4)
client.new()
  |> client.scheme(http.Http)
  |> client.host("internal-service.local")
  |> client.protocols(Http2Only)
  |> client.send()
```

### Variants

- `Http1Only` — forces HTTP/1.1 (`protocols => [http]`)
- `Http2Only` — forces HTTP/2 (`protocols => [http2]`); enables h2c for TCP, h2-only ALPN for TLS
- `Http2Preferred` — prefers HTTP/2 with fallback (`protocols => [http2, http]`)

### Defaults

When `protocols()` is not called, existing defaults apply: HTTP/2 preferred
(via ALPN) for HTTPS, HTTP/1.1 only for HTTP. No behavior change for
existing code.

### Implementation

ALPN advertisement is automatically aligned with the configured protocol
preference — if you set `Http2Only`, only `h2` is advertised during the TLS
handshake. Connections with different protocol preferences get separate pool
entries to prevent protocol mismatch.

---

## Logging migration: OTP `logger`

Internal logging has been migrated from `error_logger` and raw `io:format` to
OTP's `logger` module. Connection events (graceful closures at `info` level,
unexpected disconnects at `warning` level) and decompression warnings now go
through `logger`, enabling standard OTP log level filtering.

A new `log_level` field on `TransportConfig` controls the minimum severity for
dream_http_client's log output. It uses `logger:set_module_level/2` to scope
filtering to dream's own modules without affecting the rest of your application.

```gleam
import dream_http_client/client.{LogWarning}

client.transport_config()
|> client.log_level(LogWarning)
|> client.configure_transport()
```

Defaults to `LogInfo`. Available levels: `LogDebug`, `LogInfo`, `LogWarning`,
`LogError`, `LogNone`.

---

## Architecture

### Connection lifecycle

```
request → get_or_open_connection → ensure_connection (gen_server)
  → if below max_connections: gun:open + gun:await_up → new connection
  → if at max: round-robin from pool
  → if stale connection error: close + retry once with new connection
```

### Message routing

- **Sync requests:** `gun:await` / `gun:await_body` in the calling process
- **Pull streaming:** Owner process receives `gun_data` messages directly
- **Message streaming:** Translator process receives gun messages, forwards
  as `{http, ...}` tuples to the stream process

### Auto-redirect

gun does not handle HTTP redirects natively. The shim implements manual
redirect following for all three request paths, supporting up to 5 hops
with proper method/body handling for 301/302/303/307/308.

---

## Test coverage

235 tests (235 total across the module):

All existing tests updated for structured error types. New tests cover:
- All 13 `TransportConfig` builder/getter round-trips
- Default values, edge cases (zero/one values), builder chaining
- `configure_transport` application
- Concurrent streaming scenarios with connection pool management
- `HttpFailure` carries response headers and body
- `ConnectFailed` variant with descriptive reason
- `transport_error_to_string` and `stream_failure_to_string` helper output

---

## Files changed

- `modules/http_client/gleam.toml` — Added `gun >= 2.2.0` dependency
- `modules/http_client/src/dream_http_client/dream_http_shim.erl` — New file:
  gun-based FFI shim replacing `dream_httpc_shim.erl`
- `modules/http_client/src/dream_http_client/dream_http_conn_manager.erl` —
  New file: connection pool gen_server
- `modules/http_client/src/dream_http_client/dream_httpc_shim.erl` — Deleted
- `modules/http_client/src/dream_http_client/client.gleam` — Redesigned
  `TransportConfig` with 13 gun-native fields, updated FFI references
- `modules/http_client/src/dream_http_client/internal.gleam` — Updated
  external function references from `dream_httpc_shim` to `dream_http_shim`
- `modules/http_client/src/dream_http_client/dream_http_client_app.erl` —
  Added `dream_http_client_connections` ETS table creation
- `modules/http_client/src/dream_http_client/dream_http_client_sup.erl` —
  Added `dream_http_conn_manager` as supervised child
- `modules/http_client/test/transport_config_test.gleam` — Rewritten for
  13 gun-native TransportConfig fields
- `modules/http_client/test/snippets/transport_config_example.gleam` — Updated
- `modules/http_client/CHANGELOG.md` — 5.2.0 entry
- `modules/http_client/README.md` — Updated for gun backend

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

Error types have changed (see Structured Error Types above). The HTTP
backend has been swapped from `httpc` to `gun`. Use the migration guide
above to update error handling code.

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
