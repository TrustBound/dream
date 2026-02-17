# dream_http_client 5.0.0 Release Notes

**Release Date:** February 16, 2026

dream_http_client 5.0.0 makes `send()` return the full HTTP response — status
code, headers, and body — and introduces typed errors that distinguish HTTP
failures from transport failures at the type level.

## Why this release exists

In 4.x, `send()` returned `Result(String, String)` — just the response body on
success, and a message string on failure. This had three problems:

1. **4xx/5xx responses were invisible.** A 404 came back as `Ok(body)`, identical
   to a 200. Callers had no way to distinguish success from HTTP errors without
   parsing the body or making a second request.

2. **Response metadata was discarded.** Status codes and headers were consumed
   internally but never surfaced. If you needed a status code, Content-Type, or
   Set-Cookie header, you were out of luck.

3. **All errors were opaque strings.** Connection refused and 500 Internal Server
   Error both arrived as `Error("some message")`. Callers couldn't branch on the
   type of failure without string parsing.

5.0.0 fixes all three. `send()` now returns a structured `HttpResponse` on
success, routes HTTP errors to a typed `ResponseError` variant (with the full
response available for inspection), and wraps transport failures in a
`RequestError` variant. No new functions were added — `send()` just returns
what an HTTP client should have always returned.

## Key Highlights

- **`send()` returns `HttpResponse`** — status, headers (as `List(Header)`), and body
- **HTTP errors carry the full response** — inspect status codes, parse error bodies, read headers
- **Typed error variants** — `ResponseError` for 4xx/5xx, `RequestError` for transport failures
- **`Ok` always means success** — status < 400 guaranteed, no more silent error responses
- **Full recording/playback for all execution modes** — `send()`, `stream_yielder()`, and `start_stream()` all support recording and playback

## New Types

### `HttpResponse`

Complete HTTP response returned by `send()`:

```gleam
pub type HttpResponse {
  HttpResponse(status: Int, headers: List(Header), body: String)
}
```

- `status` — HTTP status code (200, 301, 404, 500, etc.)
- `headers` — response headers as `List(Header)`, the same type used throughout the module
- `body` — complete response body as a UTF-8 string

### `SendError`

Typed error variants returned by `send()`:

```gleam
pub type SendError {
  ResponseError(response: HttpResponse)
  RequestError(message: String)
}
```

- `ResponseError` — the server responded with status >= 400. The full `HttpResponse`
  is available with status, headers, and body (typically containing error details
  from the API).
- `RequestError` — the request never completed. Common causes: connection refused,
  DNS resolution failure, timeout, recorder errors.

## Streaming Playback for `start_stream()`

In 4.x, `start_stream()` could **record** streaming responses but could not **play
them back** from fixtures. Playback attempted to inject messages into the caller's
mailbox, which isn't possible from a recording. In practice this meant callback-based
streaming tests required real network calls every run.

5.0.0 fixes this. When a recorder is attached and a matching recording exists,
`start_stream()` replays the recorded chunks directly via your callbacks —
`on_stream_start`, `on_stream_chunk`, and `on_stream_end` are called in sequence
with the recorded data. No network calls, no delays. The same `StreamingResponse`
format used by `stream_yielder()` playback is reused, so existing recordings work
with both execution modes.

All three execution modes now fully support recording and playback:

| Mode               | Record | Playback |
|:-------------------|:------:|:--------:|
| `send()`           | ✓      | ✓        |
| `stream_yielder()` | ✓      | ✓        |
| `start_stream()`   | ✓      | ✓ (new)  |

## Breaking Changes

### 1) `send()` return type changed

**Before (4.x):**

```gleam
pub fn send(request) -> Result(String, String)
```

**After (5.0.0):**

```gleam
pub fn send(request) -> Result(HttpResponse, SendError)
```

### 2) HTTP error responses moved from `Ok` to `Error`

4xx and 5xx responses previously came back as `Ok(body)`. Now they are
`Error(ResponseError(response))` with the full `HttpResponse` available:

| Condition            | 4.x                    | 5.0.0                                      |
|:---------------------|:----------------------|:--------------------------------------------|
| Status 200           | `Ok("body")`          | `Ok(HttpResponse(status: 200, ..))`        |
| Status 404           | `Ok("not found")`     | `Error(ResponseError(response: HttpResponse(status: 404, ..)))` |
| Connection refused   | `Error("message")`    | `Error(RequestError(message: "message"))`  |

This means:

- `Ok(HttpResponse(..))` — **guaranteed** successful response (status < 400)
- `Error(ResponseError(response))` — HTTP error with the full response
- `Error(RequestError(message))` — transport/connection failure

### 3) Error strings are now typed

All `Error("some message")` values are now wrapped in `RequestError`:

```gleam
// Before:
Error("Connection refused")

// After:
Error(RequestError(message: "Connection refused"))
```

## Migration Guide

### Quick migration — just extract the body

If you only need the body and want the smallest possible diff:

**Before:**

```gleam
let assert Ok(body) = client.send(request)
```

**After:**

```gleam
let assert Ok(client.HttpResponse(body: body, ..)) = client.send(request)
```

### Recommended — full pattern match

Handle all three result cases explicitly:

```gleam
case client.send(request) {
  Ok(HttpResponse(status: status, headers: headers, body: body)) -> {
    // Guaranteed status < 400
    use_response(status, headers, body)
  }

  Error(ResponseError(response: response)) -> {
    // HTTP error (4xx/5xx) — response.body often contains error details
    handle_http_error(response.status, response.body)
  }

  Error(RequestError(message: message)) -> {
    // Connection failure, timeout, DNS error, etc.
    handle_transport_error(message)
  }
}
```

### Real-world improvement

This is why the major version bump is worth it:

**Before (4.x) — HTTP errors were invisible:**

```gleam
case client.send(request) {
  Ok(body) -> {
    // Could be 200 or 404 — no way to tell!
    // Have to parse the body to detect errors
    case json.decode(body, error_decoder) {
      Ok(api_error) -> Error(api_error.message)
      Error(_) -> Ok(body)
    }
  }
  Error(msg) -> Error(msg)
}
```

**After (5.0.0) — `Ok` always means success:**

```gleam
case client.send(request) {
  Ok(response) -> {
    // Guaranteed success — just use the body
    Ok(response.body)
  }
  Error(ResponseError(response: response)) -> {
    // HTTP error — status, headers, and body are all available
    Error("HTTP " <> int.to_string(response.status) <> ": " <> response.body)
  }
  Error(RequestError(message: msg)) -> {
    // Transport failure — no HTTP response at all
    Error("Connection failed: " <> msg)
  }
}
```

### Migrating error handling

If you were pattern matching on `Error(String)`:

**Before:**

```gleam
case client.send(request) {
  Ok(body) -> process(body)
  Error(msg) -> log_error(msg)
}
```

**After:**

```gleam
case client.send(request) {
  Ok(response) -> process(response.body)
  Error(ResponseError(response: response)) -> log_error(response.body)
  Error(RequestError(message: msg)) -> log_error(msg)
}
```

## Backward Compatibility

### What didn't change

- **Builder API** — `client.new()`, `host()`, `path()`, `method()`, `headers()`,
  `body()`, `timeout()`, etc. are all unchanged
- **Recorder API** — `recorder.new()`, `directory()`, `mode()`, `start()`, `stop()`,
  `key()`, `request_transformer()`, `response_transformer()` are all unchanged
- **Streaming APIs** — `stream_yielder()`, `start_stream()`, `await_stream()`,
  `cancel_stream_handle()`, `is_stream_active()` are all unchanged
- **Recording format** — existing fixture files on disk are fully compatible;
  `StreamingResponse` recordings created by `stream_yielder()` or `start_stream()`
  in record mode are playable by both streaming APIs

### What changed

- `send()` return type: `Result(String, String)` → `Result(HttpResponse, SendError)`
- HTTP 4xx/5xx responses: `Ok(body)` → `Error(ResponseError(response))`
- Transport errors: `Error(message)` → `Error(RequestError(message: message))`

## Test Coverage

All 134 tests pass:

```
134 passed, no failures
```

New tests added for this release:

- **Status code boundary tests** — verifies the 399/400 boundary is correct for
  200, 201, 204, 399 (all `Ok`), and 400, 401, 503 (all `Error(ResponseError)`)
- **HttpResponse field verification** — confirms status, headers, and body are
  populated correctly for both success and error responses
- **Header type verification** — confirms headers arrive as `List(Header)`, not
  raw tuples
- **Typed error verification** — confirms `ResponseError` and `RequestError`
  variants are used correctly across all error paths
- **Recording playback preservation** — verifies recorded responses preserve
  status, headers, and body through the record/playback cycle
- **Streaming recording with `stream_yielder()`** — records and plays back a
  yielder stream, verifying byte counts match
- **Streaming recording with `start_stream()`** — records and plays back a
  callback-based stream, verifying byte counts match
- **`start_stream()` playback with `StreamingResponse`** — manually creates a
  streaming recording and verifies all callbacks fire with correct data
- **`start_stream()` playback with `BlockingResponse`** — verifies the body is
  delivered as a single chunk when a blocking recording is replayed via callbacks
- **`start_stream()` playback miss** — verifies fall-through to live HTTP when
  no matching recording exists
- **`transform_response()` with transformer** — directly calls the public
  function and verifies the transformer is applied
- **`transform_response()` without transformer** — verifies the original
  response is returned unchanged when no transformer is configured

## Upgrading

Update your dependency:

```toml
[dependencies]
dream_http_client = ">= 5.0.0 and < 6.0.0"
```

Then run:

```bash
gleam deps download
```

### Downstream consumers

If you use `dream_opensearch`, update to `>= 2.1.0` which adapts to the new
`send()` return type. The `dream_opensearch` API itself is unchanged — it
continues to return `Result(String, String)` by extracting the body internally.

## Documentation

- [dream_http_client hexdocs](https://hexdocs.pm/dream_http_client) — v5.0.0
- [README](https://github.com/TrustBound/dream/tree/main/modules/http_client)
- [Tested snippets](https://github.com/TrustBound/dream/tree/main/modules/http_client/test/snippets)

## Community

- [Full Documentation](https://github.com/TrustBound/dream/tree/main/modules/http_client)
- [Discussions](https://github.com/TrustBound/dream/discussions)
- [Report Issues](https://github.com/TrustBound/dream/issues)
- [Contributing Guide](https://github.com/TrustBound/dream/blob/main/CONTRIBUTING.md)

---

**Full Changelog:** [CHANGELOG.md](https://github.com/TrustBound/dream/blob/main/modules/http_client/CHANGELOG.md)
