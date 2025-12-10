<div align="center">
  <img src="https://raw.githubusercontent.com/TrustBound/dream/main/ricky_and_lucy.png" alt="Dream Logo" width="200">
</div>

<br />

<div align="center">
  <a href="https://hex.pm/packages/dream_http_client">
    <img src="https://img.shields.io/hexpm/v/dream_http_client" alt="Hex Package">
  </a>
  <a href="https://hexdocs.pm/dream_http_client">
    <img src="https://img.shields.io/badge/hex-docs-lightgreen.svg" alt="HexDocs">
  </a>
  <a href="https://github.com/TrustBound/dream/blob/main/modules/http_client/LICENSE.md">
    <img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT License">
  </a>
  <a href="https://gleam.run">
    <img src="https://img.shields.io/badge/gleam-%E2%9C%A8-ffaff3" alt="Gleam">
  </a>
</div>

<br />

# dream_http_client

**Type-safe HTTP client for Gleam with streaming support.**

A standalone HTTP/HTTPS client built on Erlang's battle-tested `httpc`. Supports blocking requests, yielder streaming, and message-based streaming. Built with the same quality standards as [Dream](https://github.com/TrustBound/dream), but completely independent—use it in any Gleam project.

---

## Contents

- [Why dream_http_client?](#why-dream_http_client)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Execution Modes](#execution-modes)
- [Recording & Playback](#recording--playback)
- [API Reference](#api-reference)
- [Examples](#examples)

---

## Why dream_http_client?

| Feature                   | What you get                                                |
| ------------------------- | ----------------------------------------------------------- |
| **Three execution modes** | Blocking, yielder streaming, message-based—choose what fits |
| **OTP-first design**      | Message-based streams integrate with actors and selectors   |
| **Recording/playback**    | Record HTTP calls for tests, debug production, work offline |
| **Type-safe**             | `Result` types force error handling—no silent failures      |
| **Battle-tested**         | Built on Erlang's `httpc`—proven in production for decades  |
| **Framework-independent** | Zero dependencies on Dream or other frameworks              |
| **Concurrent streams**    | Handle multiple HTTP streams in a single actor              |
| **Stream cancellation**   | Cancel in-flight requests cleanly                           |
| **Builder pattern**       | Consistent, composable request configuration                |

---

## Installation

```bash
gleam add dream_http_client
```

---

## Quick Start

Make a simple HTTP request:

```gleam
import dream_http_client/client
import gleam/http

pub fn fetch_data() {
  client.new
  |> client.method(http.Get)
  |> client.scheme(http.Https)
  |> client.host("api.example.com")
  |> client.path("/users/123")
  |> client.add_header("Authorization", "Bearer " <> token)
  |> client.send()
}
```

<sub>🧪 [Tested source](test/snippets/blocking_request.gleam)</sub>

---

## Execution Modes

dream_http_client provides three execution modes. Choose based on your use case:

### 1. Blocking - `send()`

**Best for:** JSON APIs, small responses

```gleam
let result = client.new
  |> client.host("api.example.com")
  |> client.path("/users")
  |> client.send()

case result {
  Ok(body) -> decode_json(body)
  Error(msg) -> handle_error(msg)
}
```

<sub>🧪 [Tested source](test/snippets/blocking_request.gleam)</sub>

### 2. Yielder Streaming - `stream_yielder()`

**Best for:** AI/LLM streaming, file downloads, sequential processing

```gleam
import gleam/yielder

client.new
  |> client.host("api.openai.com")
  |> client.path("/v1/chat/completions")
  |> client.stream_yielder()
  |> yielder.each(fn(chunk_result) {
    case chunk_result {
      Ok(chunk) -> process_chunk(chunk)
      Error(reason) -> log_error(reason)
    }
  })
```

<sub>🧪 [Tested source](test/snippets/stream_yielder_basic.gleam)</sub>

**⚠️ Note:** This blocks while waiting for chunks. Not suitable for OTP actors handling concurrent operations.

### 3. Process-Based Streaming - `start_stream()`

**Best for:** Background tasks, concurrent operations, cancellable streams

```gleam
// Start stream with callbacks - returns immediately
let assert Ok(stream) = client.new
  |> client.host("api.openai.com")
  |> client.path("/v1/chat/completions")
  |> client.on_stream_chunk(fn(data) {
    case bit_array.to_string(data) {
      Ok(text) -> io.print(text)
      Error(_) -> Nil
    }
  })
  |> client.start_stream()

// Wait for completion if needed
client.await_stream(stream)

// Or cancel early
client.cancel_stream_handle(stream)
```

<sub>🧪 [Tested source](test/snippets/stream_messages_basic.gleam)</sub>

### Choosing a Mode

| Use Case                          | Mode               | Why                                   |
| --------------------------------- | ------------------ | ------------------------------------- |
| JSON API calls                    | `send()`           | Simple, complete response at once     |
| Small file downloads              | `send()`           | Load entire file into memory          |
| AI/LLM streaming (single request) | `stream_yielder()` | Sequential token processing           |
| File downloads                    | `stream_yielder()` | Memory-efficient chunked processing   |
| Background processing             | `start_stream()`   | Non-blocking, concurrent, cancellable |
| Long-lived connections            | `start_stream()`   | Can cancel mid-stream                 |
| Cancellable operations            | `start_stream()`   | Cancel via handle                     |

---

## Recording & Playback

Record HTTP requests/responses for testing, debugging, and offline development.

### Quick Example

```gleam
import dream_http_client/recorder
import dream_http_client/matching

// Record real requests
let assert Ok(rec) = recorder.start(
  recorder.Record(directory: "mocks/api"),
  matching.match_url_only(),
)

client.new
  |> client.host("api.example.com")
  |> client.recorder(rec)
  |> client.send()  // Saved immediately to disk

// Playback later (no network)
let assert Ok(playback) = recorder.start(
  recorder.Playback(directory: "mocks/api"),
  matching.match_url_only(),
)

client.new
  |> client.host("api.example.com")
  |> client.recorder(playback)
  |> client.send()  // Returns recorded response
```

<sub>🧪 [Tested source](test/snippets/recording_basic.gleam)</sub>

### Recording Modes

- **`Record(directory)`** - Records real requests to disk immediately
- **`Playback(directory)`** - Returns recorded responses (no network)
- **`Passthrough`** - No recording/playback

**Important:** Recordings are saved immediately when captured. `recorder.stop()` is optional and only performs cleanup. This ensures recordings are never lost even if the process crashes.

### Use Cases

**Testing:**

```gleam
// test/api_test.gleam
let assert Ok(rec) = recorder.start(
  recorder.Playback(directory: "test/fixtures/api"),
  matching.match_url_only(),
)
// Tests run without external dependencies
```

<sub>🧪 [Tested source](test/snippets/recording_playback.gleam)</sub>

**Offline Development:**
Record API responses once, then work offline using recorded responses.

**Debugging Production:**
Record problematic request/response pairs for investigation.

### Request Matching

```gleam
import dream_http_client/matching

// Default: Match on method + URL only
let config = matching.match_url_only()

// Custom matching
let config = matching.MatchingConfig(
  match_method: True,
  match_url: True,
  match_headers: False,  // Ignore auth tokens, timestamps
  match_body: False,     // Ignore request IDs in body
)
```

<sub>🧪 [Tested source](test/snippets/matching_config.gleam)</sub>

### Recording Storage

Recordings are stored as individual files (one per request) with human-readable filenames:

```
mocks/api/GET_api.example.com_users_a3f5b2.json
mocks/api/POST_api.example.com_users_c7d8e9.json
```

**Benefits:**

- **O(1) write performance** - No read-modify-write cycles
- **Concurrent tests work** - No file contention between parallel tests
- **Easy inspection** - Each recording is a separate, readable file
- **Version control friendly** - Individual files show clear diffs

---

## API Reference

### Builder Pattern

```gleam
client.new
|> client.method(http.Post)         // HTTP method
|> client.scheme(http.Https)        // HTTP or HTTPS
|> client.host("api.example.com")   // Hostname (required)
|> client.port(443)                 // Port (optional, defaults 80/443)
|> client.path("/api/users")        // Request path
|> client.query("page=1&limit=10")  // Query string
|> client.add_header("Content-Type", "application/json")
|> client.body(json_body)           // Request body
|> client.timeout(60_000)           // Timeout in ms (default: 30s)
```

<sub>🧪 [Tested source](test/snippets/request_builder.gleam)</sub>

### Execution

**Blocking:**

- `send(req) -> Result(String, String)` - Returns complete response body

**Yielder Streaming:**

- `stream_yielder(req) -> Yielder(Result(BytesTree, String))` - Returns yielder producing chunks

**Message-Based Streaming:**

- `stream_messages(req) -> Result(RequestId, String)` - Starts stream, returns ID
- `select_stream_messages(selector, mapper) -> Selector(msg)` - Integrates with OTP selectors
- `cancel_stream(request_id)` - Cancels active stream

### Types

**`RequestId`** - Opaque identifier for message-based streams

**`StreamMessage`**:

- `StreamStart(request_id, headers)` - Stream started
- `Chunk(request_id, data)` - Data chunk received
- `StreamEnd(request_id, headers)` - Stream completed
- `StreamError(request_id, reason)` - Stream failed
- `DecodeError(reason)` - FFI corruption (report as bug)

### Error Handling

All modes use `Result` types for explicit error handling:

```gleam
case client.send(request) {
  Ok(body) -> process_response(body)
  Error(msg) -> {
    // Common errors:
    // - Connection refused
    // - DNS resolution failed
    // - Timeout
    log_error(msg)
  }
}
```

<sub>🧪 [Tested source](test/snippets/timeout_config.gleam)</sub>

---

## Examples

All examples are tested and verified. See [test/snippets/](test/snippets/) for complete, runnable code.

**Basic requests:**

- [Blocking request](test/snippets/blocking_request.gleam) - Simple GET
- [POST with JSON](test/snippets/post_json.gleam) - JSON body
- [Request builder](test/snippets/request_builder.gleam) - Full configuration
- [Timeout configuration](test/snippets/timeout_config.gleam) - Custom timeouts

**Streaming:**

- [Yielder streaming](test/snippets/stream_yielder_basic.gleam) - Sequential processing

**Recording:**

- [Record and playback](test/snippets/recording_basic.gleam) - Testing without network

---

## Design Principles

This module follows the same quality standards as [Dream](https://github.com/TrustBound/dream):

- **No nested cases** - Clear, flat control flow throughout
- **No anonymous functions** - All functions are named for clarity
- **Builder pattern** - Consistent, composable request configuration
- **Type safety** - `Result` types force error handling at compile time
- **OTP-first design** - Message-based API designed for supervision trees
- **Comprehensive testing** - Unit tests (no network) + integration tests (real HTTP)
- **Battle-tested foundation** - Built on Erlang's production-proven `httpc`

---

## About Dream

This module was originally built for the [Dream](https://github.com/TrustBound/dream) web toolkit, but it's completely standalone and can be used in any Gleam project. It follows Dream's design principles and will be maintained as part of the Dream ecosystem.

---

## License

MIT — see [LICENSE.md](LICENSE.md)

---

<div align="center">
  <sub>Built in Gleam, on the BEAM, by the <a href="https://github.com/trustbound/dream">Dream Team</a> ❤️</sub>
</div>
