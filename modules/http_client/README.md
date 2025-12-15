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

**Type-safe HTTP client for Gleam with recording + streaming support.**

A standalone HTTP/HTTPS client built on Erlang's battle-tested `httpc`. Supports blocking requests, yielder streaming, and process-based streaming via callbacks. Built with the same quality standards as [Dream](https://github.com/TrustBound/dream), but completely independent—use it in any Gleam project.

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
| **Three execution modes** | Blocking, yielder streaming, process-based—choose what fits |
| **OTP-first design**      | Process-based streams work great with OTP                   |
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
import dream_http_client/client.{host, method, path, port, scheme, send}
import gleam/http

pub fn simple_get() -> Result(String, String) {
  client.new()
  |> method(http.Get)
  |> scheme(http.Http)
  |> host("localhost")
  |> port(9876)
  |> path("/text")
  |> send()
}
```

<sub>🧪 [Tested source](test/snippets/blocking_request.gleam)</sub>

---

## Execution Modes

dream_http_client provides three execution modes. Choose based on your use case:

### 1. Blocking - `send()`

**Best for:** JSON APIs, small responses

```gleam
import dream_http_client/client.{host, path, port, scheme, send}
import gleam/http

let result =
  client.new()
  |> scheme(http.Http)
  |> host("localhost")
  |> port(9876)
  |> path("/text")
  |> send()

case result {
  Ok(body) -> Ok(body)
  Error(msg) -> Error(msg)
}
```

<sub>🧪 [Tested source](test/snippets/blocking_request.gleam)</sub>

### 2. Yielder Streaming - `stream_yielder()`

**Best for:** AI/LLM streaming, file downloads, sequential processing

```gleam
import dream_http_client/client.{host, path, port, scheme, stream_yielder}
import gleam/bytes_tree
import gleam/http
import gleam/yielder

let total_bytes =
  client.new()
  |> scheme(http.Http)
  |> host("localhost")
  |> port(9876)
  |> path("/stream/fast")
  |> stream_yielder()
  |> yielder.fold(0, fn(total, chunk_result) {
    case chunk_result {
      Ok(chunk) -> total + bytes_tree.byte_size(chunk)
      Error(_) -> total
    }
  })
```

<sub>🧪 [Tested source](test/snippets/stream_yielder_basic.gleam)</sub>

**⚠️ Note:** This blocks while waiting for chunks. Not suitable for OTP actors handling concurrent operations.

### 3. Process-Based Streaming - `start_stream()`

**Best for:** Background tasks, concurrent operations, cancellable streams

```gleam
import dream_http_client/client.{
  await_stream, host, on_stream_chunk, on_stream_end, on_stream_error,
  on_stream_start, path, port, scheme, start_stream,
}
import gleam/bit_array
import gleam/http
import gleam/io

pub fn stream_and_print() -> Result(Nil, String) {
  let stream_result =
    client.new()
    |> scheme(http.Http)
    |> host("localhost")
    |> port(9876)
    |> path("/stream/fast")
    |> on_stream_start(fn(_headers) { io.println("Stream started") })
    |> on_stream_chunk(fn(data) {
      case bit_array.to_string(data) {
        Ok(text) -> io.print(text)
        Error(_) -> io.print("<binary>")
      }
    })
    |> on_stream_end(fn(_headers) { io.println("\nStream completed") })
    |> on_stream_error(fn(reason) {
      io.println_error("Stream error: " <> reason)
    })
    |> start_stream()

  case stream_result {
    Error(reason) -> Error(reason)
    Ok(stream_handle) -> {
      await_stream(stream_handle)
      Ok(Nil)
    }
  }
}
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
import dream_http_client/recorder.{directory, mode, start}
import dream_http_client/client.{host, path, port, recorder as with_recorder, scheme, send}
import gleam/http

// Record real requests
let assert Ok(rec) =
  recorder.new()
  |> directory("mocks/api")
  |> mode("record")
  |> start()

client.new()
  |> scheme(http.Http)
  |> host("localhost")
  |> port(9876)
  |> path("/text")
  |> with_recorder(rec)
  |> send()  // Saved immediately to disk

// Playback later (no network)
let assert Ok(playback) =
  recorder.new()
  |> directory("mocks/api")
  |> mode("playback")
  |> start()

client.new()
  |> scheme(http.Http)
  |> host("localhost")
  |> port(9876)
  |> path("/text")
  |> with_recorder(playback)
  |> send()  // Returns recorded response
```

<sub>🧪 [Tested source](test/snippets/recording_basic.gleam)</sub>

### Recording Modes

- **`"record"`** - Records real requests to disk immediately
- **`"playback"`** - Returns recorded responses (no network)
- **`"passthrough"`** - No recording/playback

**Important:** Recordings are saved immediately when captured. `recorder.stop()` is optional and only performs cleanup. This ensures recordings are never lost even if the process crashes.

### Use Cases

**Testing:**

```gleam
// test/api_test.gleam
import dream_http_client/recorder.{directory, mode, start}

let assert Ok(rec) =
  recorder.new()
  |> directory("test/fixtures/api")
  |> mode("playback")
  |> start()

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
import dream_http_client/recorder.{directory, key, mode, start}

// Build a request key function from include/exclude flags
let request_key_fn = matching.request_key(
  method: True,
  url: True,
  headers: False,  // Ignore auth tokens, timestamps
  body: False,     // Ignore request IDs in body
)

let assert Ok(rec) =
  recorder.new()
  |> directory("mocks/api")
  |> mode("playback")
  |> key(request_key_fn)
  |> start()
```

<sub>🧪 [Tested source](test/snippets/matching_config.gleam)</sub>

### Scrubbing Secrets (Transformers)

If your requests contain secrets (like `Authorization` headers) or volatile fields (timestamps, request IDs),
you can attach a transformer to **normalize** requests _before_ the key is computed and before anything is persisted.

```gleam
import dream_http_client/matching
import dream_http_client/recorder.{
  directory, key, mode, request_transformer, start,
}
import dream_http_client/recording
import gleam/list

let request_key_fn =
  matching.request_key(method: True, url: True, headers: True, body: True)

fn scrub_auth_and_body(
  request: recording.RecordedRequest,
) -> recording.RecordedRequest {
  fn is_not_authorization_header(header: #(String, String)) -> Bool {
    header.0 != "Authorization"
  }

  let recording.RecordedRequest(
    method,
    scheme,
    host,
    port,
    path,
    query,
    headers,
    _body,
  ) = request

  let scrubbed_headers =
    list.filter(headers, is_not_authorization_header)

  recording.RecordedRequest(
    method: method,
    scheme: scheme,
    host: host,
    port: port,
    path: path,
    query: query,
    headers: scrubbed_headers,
    body: "",
  )
}

let assert Ok(rec) =
  recorder.new()
  |> directory("mocks/api")
  |> mode("record")
  |> key(request_key_fn)
  |> request_transformer(scrub_auth_and_body)
  |> start()

// ... requests recorded via this recorder will have secrets scrubbed ...
```

<sub>🧪 [Tested source](test/snippets/recording_transformer.gleam)</sub>

If you need to scrub **responses** (cookies, tokens, PII) before fixtures are written to disk, use a response transformer.
This runs **only in record mode**.

```gleam
import dream_http_client/recorder.{directory, mode, response_transformer, start}
import dream_http_client/recording

fn scrub_response(
  _request: recording.RecordedRequest,
  response: recording.RecordedResponse,
) -> recording.RecordedResponse {
  // Implementation omitted here (see tested snippet)
  response
}

let assert Ok(rec) =
  recorder.new()
  |> directory("mocks/api")
  |> mode("record")
  |> response_transformer(scrub_response)
  |> start()
```

<sub>🧪 [Tested source](test/snippets/recording_response_transformer.gleam)</sub>

### Ambiguous Matches (Key Collisions)

Playback **errors** if more than one recording matches the same request key. This is intentional: it forces you to
refine your key function (or add a transformer) so each request maps to exactly one recording.

```gleam
import dream_http_client/matching
import dream_http_client/recorder.{directory, key, mode, start}

let request_key_fn =
  matching.request_key(method: True, url: True, headers: False, body: False)

let assert Ok(playback) =
  recorder.new()
  |> directory("mocks/api")
  |> mode("playback")
  |> key(request_key_fn)
  |> start()

// ... lookup will return Error("Ambiguous recording match ...") if multiple match ...
```

<sub>🧪 [Tested source](test/snippets/recording_ambiguous_match.gleam)</sub>

### Recording Storage

Recordings are stored as individual files (one per request) with human-readable filenames:

- Filename format: `{method}_{host}_{path}_{key_hash}_{content_hash}.json`
- **`key_hash`** groups recordings by request key
- **`content_hash`** prevents overwrites when multiple recordings share the same key

```
mocks/api/GET_localhost__text_a3f5b2_19d0a1.json
mocks/api/POST_localhost__text_c7d8e9_4f22bc.json
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
import dream_http_client/client.{
  add_header, body, host, method, path, port, query, scheme, send, timeout,
}
import gleam/http

let json_body = "{\"hello\":\"world\"}"

client.new()
|> method(http.Post)         // HTTP method
|> scheme(http.Http)         // HTTP or HTTPS
|> host("localhost")         // Hostname (required)
|> port(9876)                // Port (optional, defaults 80/443)
|> path("/post")             // Request path
|> query("page=1&limit=10")  // Query string
|> add_header("Content-Type", "application/json")
|> body(json_body)           // Request body
|> timeout(60_000)           // Timeout in ms (default: 30s)
|> send()
```

<sub>🧪 [Tested source](test/snippets/request_builder.gleam)</sub>

### Execution

**Blocking:**

- `send(req) -> Result(String, String)` - Returns complete response body

**Yielder Streaming:**

- `stream_yielder(req) -> Yielder(Result(BytesTree, String))` - Returns yielder producing chunks

**Process-Based Streaming:**

- `start_stream(req) -> Result(StreamHandle, String)` - Starts stream, returns handle
- `await_stream(handle) -> Nil` - Wait for completion (optional)
- `cancel_stream_handle(handle) -> Nil` - Cancel running stream

### Types

**`StreamHandle`** - Opaque identifier for process-based streams

### Error Handling

All modes use `Result` types for explicit error handling:

```gleam
import dream_http_client/client.{host, path, port, scheme, send, timeout}
import gleam/http
import gleam/io

let request =
  client.new()
  |> scheme(http.Http)
  |> host("localhost")
  |> port(9876)
  |> path("/text")
  |> timeout(5000)

case send(request) {
  Ok(body) -> {
    io.println(body)
    Ok(body)
  }
  Error(msg) -> {
    io.println_error("Request failed: " <> msg)
    Error(msg)
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
- [Process-based streaming](test/snippets/stream_messages_basic.gleam) - Callback-driven streaming
- [Stream cancellation](test/snippets/stream_cancel.gleam) - Cancel via `StreamHandle`

**Recording:**

- [Record and playback](test/snippets/recording_basic.gleam) - Testing without network
- [Playback-only testing](test/snippets/recording_playback.gleam) - Test fixtures without network
- [Custom request keys](test/snippets/matching_config.gleam) - Configure request matching
- [Request transformers](test/snippets/recording_transformer.gleam) - Scrub secrets before keying/persistence
- [Response transformers](test/snippets/recording_response_transformer.gleam) - Scrub secrets from recorded responses
- [Ambiguous match errors](test/snippets/recording_ambiguous_match.gleam) - Key collision behavior

---

## Design Principles

This module follows the same quality standards as [Dream](https://github.com/TrustBound/dream):

- **No nested cases** - Clear, flat control flow throughout
- **Prefer named functions** - Use named functions when it improves readability
- **Builder pattern** - Consistent, composable request configuration
- **Type safety** - `Result` types force error handling at compile time
- **OTP-first design** - Process-based streaming designed for supervision trees
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
