<div align="center">
  <img src="https://raw.githubusercontent.com/TrustBound/dream/main/ricky_and_lucy.png" alt="Dream Logo" width="200">
  
  <a href="https://hexdocs.pm/dream_http_client">
    <img src="https://img.shields.io/badge/hex-docs-lightgreen.svg" alt="HexDocs">
  </a>
</div>

# dream_http_client

**Type-safe HTTP client for Gleam with streaming support.**

A standalone HTTP/HTTPS client built on Erlang's battle-tested `httpc`. Supports both streaming and non-streaming requests. Built with the same quality standards as [Dream](https://github.com/TrustBound/dream), but completely independent—use it in any Gleam project.

## Features

- ✅ **Three execution modes**: Blocking, yielder streaming, and message-based streaming
- ✅ **Recording and playback**: Record HTTP requests/responses for testing and offline development
- ✅ **OTP-compatible**: Message-based streams work with actors and selectors
- ✅ **Concurrent streams**: Handle multiple HTTP streams in a single actor
- ✅ **Stream cancellation**: Cancel in-flight requests cleanly
- ✅ **HTTPS support**: Full TLS/SSL support via Erlang
- ✅ **Builder pattern**: Consistent, composable request configuration
- ✅ **Type-safe**: `Result` types force error handling
- ✅ **Battle-tested**: Erlang's `httpc` under the hood
- ✅ **Framework-independent**: Zero dependencies on Dream or other frameworks

## Installation

```bash
gleam add dream_http_client
```

## Quick Start

Choose the execution mode that fits your use case:

### 1. Blocking Requests - `client.send()`

Perfect for JSON APIs and small responses:

```gleam
import dream_http_client/client.{method, scheme, host, path, add_header, send}
import gleam/http.{Get, Https}

let result = client.new
  |> method(Get)
  |> scheme(Https)
  |> host("api.example.com")
  |> path("/users/123")
  |> add_header("Authorization", "Bearer " <> token)
  |> send()

case result {
  Ok(body) -> decode_json(body)
  Error(msg) -> handle_error(msg)
}
```

### 2. Yielder-Based Streaming - `client.stream_yielder()`

Perfect for AI responses or simple sequential streaming:

```gleam
import dream_http_client/client.{host, path, stream_yielder}
import gleam/yielder.{each}
import gleam/bytes_tree.{to_string}
import gleam/io.{print}

client.new
  |> host("api.openai.com")
  |> path("/v1/chat/completions")
  |> stream_yielder()
  |> each(fn(chunk) {
    // Process each chunk as it arrives
    print(to_string(chunk))
  })
```

**Note:** This is a pull-based synchronous API. It blocks while waiting for chunks,
so it's not suitable for OTP actors that need to handle multiple concurrent operations.

### 3. Message-Based Streaming - `client.stream_messages()`

Perfect for OTP actors handling multiple concurrent streams:

```gleam
import dream_http_client/client.{
  type RequestId, type StreamMessage, StreamStart, Chunk, StreamEnd, StreamError,
  host, path, stream_messages, select_stream_messages, cancel_stream
}
import gleam/otp/actor.{continue}
import gleam/erlang/process.{type Selector, new_selector}
import gleam/dict.{type Dict}

pub type Message {
  HttpStream(StreamMessage)
  OtherMessage(String)
}

pub type State {
  State(active_streams: Dict(RequestId, StreamState))
}

fn handle_message(msg: Message, state: State) {
  case msg {
    HttpStream(stream_msg) -> {
      case stream_msg {
        StreamStart(req_id, headers) -> {
          // Stream started, headers received
          let new_state = track_stream(state, req_id, headers)
          continue(new_state)
        }
        Chunk(req_id, data) -> {
          // Data chunk received, process it
          let new_state = process_chunk(state, req_id, data)
          continue(new_state)
        }
        StreamEnd(req_id, trailing_headers) -> {
          // Stream completed successfully
          let new_state = cleanup_stream(state, req_id)
          continue(new_state)
        }
        StreamError(req_id, reason) -> {
          // Stream failed, handle error
          let new_state = handle_stream_error(state, req_id, reason)
          continue(new_state)
        }
      }
    }
    OtherMessage(content) -> {
      // Handle other actor messages
      continue(state)
    }
  }
}

fn init_selector() -> Selector(Message) {
  new_selector()
  |> select_stream_messages(HttpStream)
  // Can add more selectors for other message types
}

// Start multiple concurrent streams
pub fn start_streams() {
  let assert Ok(req_id_1) = client.new
    |> host("api.example.com")
    |> path("/stream/1")
    |> stream_messages()
  
  let assert Ok(req_id_2) = client.new
    |> host("api.example.com")
    |> path("/stream/2")
    |> stream_messages()
  
  // Both streams send messages to your actor concurrently
  // RequestId discriminates between them
}

// Cancel a stream if needed
pub fn cancel_if_needed(req_id: RequestId) {
  cancel_stream(req_id)
  // No more messages will arrive for this stream
}
```

## Choosing an Execution Mode

| Use Case | Recommended Mode | Why |
|----------|------------------|-----|
| JSON API calls | `send()` | Simple, complete response at once |
| Small file downloads | `send()` | Load entire file into memory |
| AI/LLM streaming (single request) | `stream_yielder()` | Sequential token processing |
| Simple file downloads | `stream_yielder()` | Memory-efficient chunked processing |
| OTP actors with multiple streams | `stream_messages()` | Non-blocking, concurrent, cancellable |
| Long-lived connections | `stream_messages()` | Can cancel mid-stream |
| Integration with supervisors | `stream_messages()` | Full OTP compatibility |

## Usage

### Building Requests

All three execution modes use the same builder pattern:

```gleam
import dream_http_client/client.{
  method, scheme, host, port, path, query, add_header, body, timeout
}
import gleam/http.{Post, Https}

let request = client.new
  |> method(Post)
  |> scheme(Https)
  |> host("api.example.com")
  |> port(443)
  |> path("/api/users")
  |> query("page=1&limit=10")
  |> add_header("Content-Type", "application/json")
  |> add_header("Authorization", "Bearer " <> token)
  |> body(json_body)
  |> timeout(60_000)  // 60 second timeout for slow APIs
```

### Blocking Requests - `send()`

Get the complete response body at once:

```gleam
import dream_http_client/client.{send}
import gleam/json.{decode}

case send(request) {
  Ok(body) -> {
    // Process complete response
    case decode(body, user_decoder) {
      Ok(user) -> Ok(user)
      Error(_) -> Error("Invalid JSON")
    }
  }
  Error(msg) -> Error("Request failed: " <> msg)
}
```

### Yielder Streaming - `stream_yielder()`

Process chunks sequentially as they arrive:

```gleam
import dream_http_client/client.{stream_yielder}
import gleam/yielder.{each, to_list}
import gleam/bytes_tree.{to_string}
import gleam/io.{println}

// Process chunks incrementally
stream_yielder(request)
  |> each(fn(chunk) {
    let text = to_string(chunk)
    println("Received: " <> text)
  })

// Or collect all chunks (stream completes automatically)
let chunks = stream_yielder(request)
  |> to_list()  // No need to use take() - stream stops when done!
```

**Important:** This blocks the calling process while waiting for chunks.
Don't use this in OTP actors that need to handle other messages concurrently.

### Message-Based Streaming - `stream_messages()`

Handle streams in OTP actors with full concurrency:

```gleam
import dream_http_client/client.{stream_messages, select_stream_messages, cancel_stream}
import gleam/erlang/process.{new_selector}

// 1. Start a stream - returns immediately with RequestId
let assert Ok(req_id) = stream_messages(request)

// 2. Messages arrive in your process mailbox automatically:
//    - StreamStart(req_id, headers)
//    - Chunk(req_id, data) (zero or more)
//    - StreamEnd(req_id, headers) or StreamError(req_id, reason)

// 3. Use select_stream_messages to integrate with your selector
let selector = new_selector()
  |> select_stream_messages(MyHttpMessage)

// 4. Cancel if needed
cancel_stream(req_id)
```

#### Complete OTP Actor Example

```gleam
import dream_http_client/client.{
  type StreamMessage, StreamStart, Chunk, StreamEnd, StreamError,
  host, stream_messages, select_stream_messages
}
import gleam/otp/actor.{type Next, type Spec, Spec, Ready, Stop, continue, start_spec}
import gleam/erlang/process.{type Selector, Normal, new_selector, selecting}
import gleam/dict.{type Dict, new as new_dict, insert, get, delete}
import gleam/list.{reverse}
import gleam/bit_array.{concat}
import gleam/string.{inspect}
import gleam/io.{println_error}

pub type Message {
  StartDownload(url: String)
  HttpStream(StreamMessage)
  Stop
}

pub type StreamState {
  StreamState(chunks: List(BitArray))
}

pub type State {
  State(streams: Dict(String, StreamState))
}

pub fn start() {
  start_spec(Spec(
    init: fn() {
      let selector = new_selector()
        |> select_stream_messages(HttpStream)
        |> selecting(some_subject, fn(msg) { msg })
      
      Ready(State(streams: new_dict()), selector)
    },
    init_timeout: 1000,
    loop: handle_message,
  ))
}

fn handle_message(msg: Message, state: State) -> Next(Message, State) {
  case msg {
    StartDownload(url) -> {
      // Start a new stream
      let assert Ok(req_id) = client.new
        |> host(url)
        |> stream_messages()
      
      continue(state)
    }
    
    HttpStream(StreamStart(req_id, headers)) -> {
      // Stream started, initialize state
      let req_id_str = inspect(req_id)
      let new_streams = insert(
        state.streams,
        req_id_str,
        StreamState(chunks: [])
      )
      continue(State(streams: new_streams))
    }
    
    HttpStream(Chunk(req_id, data)) -> {
      // Accumulate chunk
      let req_id_str = inspect(req_id)
      case get(state.streams, req_id_str) {
        Ok(stream_state) -> {
          let updated = StreamState(
            chunks: [data, ..stream_state.chunks]
          )
          let new_streams = insert(state.streams, req_id_str, updated)
          continue(State(streams: new_streams))
        }
        Error(_) -> continue(state)
      }
    }
    
    HttpStream(StreamEnd(req_id, _headers)) -> {
      // Stream complete, process all chunks
      let req_id_str = inspect(req_id)
      case get(state.streams, req_id_str) {
        Ok(stream_state) -> {
          // Combine all chunks and process
          let complete_data = stream_state.chunks
            |> reverse()
            |> concat()
          
          process_complete_download(complete_data)
          
          // Remove from active streams
          let new_streams = delete(state.streams, req_id_str)
          continue(State(streams: new_streams))
        }
        Error(_) -> continue(state)
      }
    }
    
    HttpStream(StreamError(req_id, reason)) -> {
      // Handle error
      println_error("Stream error: " <> reason)
      let req_id_str = inspect(req_id)
      let new_streams = delete(state.streams, req_id_str)
      continue(State(streams: new_streams))
    }
    
    Stop -> Stop(Normal)
  }
}
```

### POST Requests with JSON

```gleam
import dream_http_client/client.{method, host, path, add_header, body, send}
import gleam/http.{Post}
import gleam/json.{object, string, to_string}

let user_json = object([
  #("name", string("Alice")),
  #("email", string("alice@example.com")),
])

let result = client.new
  |> method(Post)
  |> host("api.example.com")
  |> path("/users")
  |> add_header("Content-Type", "application/json")
  |> body(to_string(user_json))
  |> send()
```

### Configuring Timeouts

All request types support timeout configuration. Default is 30 seconds:

```gleam
import dream_http_client/client.{host, path, timeout, send}

// Short timeout for quick APIs
let result = client.new
  |> host("api.example.com")
  |> path("/health")
  |> timeout(5_000)  // 5 seconds
  |> send()

// Long timeout for slow operations
let result = client.new
  |> host("ml-api.example.com")
  |> path("/train-model")
  |> timeout(300_000)  // 5 minutes
  |> stream_yielder()  // Works with all execution modes
```

## Recording and Playback

Record HTTP request/response pairs to files for testing, debugging, or offline development. Supports both blocking and streaming requests.

### Quick Example

```gleam
import dream_http_client/client
import dream_http_client/recorder
import dream_http_client/matching

// 1. Record real HTTP requests
let assert Ok(rec) = recorder.start(
  mode: recorder.Record(directory: "mocks/api"),
  matching: matching.match_url_only(),
)

client.new
  |> client.host("api.example.com")
  |> client.path("/users")
  |> client.recorder(rec)  // Attach recorder
  |> client.send()  // Makes real request, records response

recorder.stop(rec)  // Saves recordings to mocks/api/recordings.json

// 2. Playback recorded responses (no network calls)
let assert Ok(playback_rec) = recorder.start(
  mode: recorder.Playback(directory: "mocks/api"),
  matching: matching.match_url_only(),
)

client.new
  |> client.host("api.example.com")
  |> client.path("/users")
  |> client.recorder(playback_rec)
  |> client.send()  // Returns recorded response instantly
```

### Recording Modes

#### Record Mode - Capture Real Requests

```gleam
import dream_http_client/recorder

let assert Ok(rec) = recorder.start(
  mode: recorder.Record(directory: "mocks"),
  matching: matching.match_url_only(),
)

// Make multiple requests - all recorded in memory
client.new |> client.host("api.example.com") |> client.path("/users") |> client.recorder(rec) |> client.send()
client.new |> client.host("api.example.com") |> client.path("/posts") |> client.recorder(rec) |> client.send()

// Save all recordings to disk
recorder.stop(rec)  // Creates mocks/recordings.json
```

#### Playback Mode - Use Recorded Responses

```gleam
let assert Ok(rec) = recorder.start(
  mode: recorder.Playback(directory: "mocks"),
  matching: matching.match_url_only(),
)

// Returns recorded response, no network call
let assert Ok(body) = client.new
  |> client.host("api.example.com")
  |> client.path("/users")
  |> client.recorder(rec)
  |> client.send()

recorder.stop(rec)
```

#### Passthrough Mode - No Recording

```gleam
let assert Ok(rec) = recorder.start(
  mode: recorder.Passthrough,
  matching: matching.match_url_only(),
)

// Makes real request, no recording
client.new
  |> client.host("api.example.com")
  |> client.recorder(rec)
  |> client.send()
```

### Streaming Requests

Recording works with all execution modes:

```gleam
// Record streaming request
let assert Ok(rec) = recorder.start(
  mode: recorder.Record(directory: "mocks/streaming"),
  matching: matching.match_url_only(),
)

client.new
  |> client.host("api.openai.com")
  |> client.path("/v1/chat/completions")
  |> client.recorder(rec)
  |> client.stream_yielder()
  |> yielder.each(process_chunk)

recorder.stop(rec)  // Saves chunks with timing

// Playback streaming request - chunks returned with preserved timing
let assert Ok(playback_rec) = recorder.start(
  mode: recorder.Playback(directory: "mocks/streaming"),
  matching: matching.match_url_only(),
)

client.new
  |> client.host("api.openai.com")
  |> client.path("/v1/chat/completions")
  |> client.recorder(playback_rec)
  |> client.stream_yielder()  // Plays back recorded chunks
  |> yielder.to_list()
```

### Request Matching

Configure how requests are matched to recordings:

```gleam
import dream_http_client/matching

// Default: Match on method + URL only
let config = matching.match_url_only()

// Custom matching
let config = matching.MatchingConfig(
  match_method: True,
  match_url: True,
  match_headers: False,  // Ignore auth tokens, timestamps, etc.
  match_body: False,     // Ignore request IDs in body
)

let assert Ok(rec) = recorder.start(
  mode: recorder.Playback(directory: "mocks"),
  matching: config,
)
```

### Use Cases

**Testing Without External Dependencies:**
```gleam
// test/api_test.gleam
pub fn get_user_profile_test() {
  let assert Ok(rec) = recorder.start(
    mode: recorder.Playback(directory: "test/fixtures/api"),
    matching: matching.match_url_only(),
  )

  let result = api.get_user_profile("user123", rec)
  
  result |> should.be_ok()
  recorder.stop(rec) |> result.unwrap(Nil)
}
```

**Offline Development:**
```gleam
// Record API responses once
let assert Ok(rec) = recorder.start(
  mode: recorder.Record(directory: "dev/api_cache"),
  matching: matching.match_url_only(),
)

// Make real API calls
let _ = fetch_user_data(rec)
let _ = fetch_product_catalog(rec)

recorder.stop(rec)

// Later: Work offline using recorded responses
let assert Ok(playback_rec) = recorder.start(
  mode: recorder.Playback(directory: "dev/api_cache"),
  matching: matching.match_url_only(),
)

// No network needed!
let _ = fetch_user_data(playback_rec)
```

**Debugging Production Issues:**
```gleam
// Record problematic request/response
let assert Ok(rec) = recorder.start(
  mode: recorder.Record(directory: "debug/issue-123"),
  matching: matching.match_url_only(),
)

// Reproduce issue
reproduce_bug(rec)
recorder.stop(rec)

// Check recording file to inspect exact request/response
```

### Recording Format

Recordings are stored as JSON in `{directory}/recordings.json`:

```json
{
  "version": "1.0",
  "entries": [
    {
      "request": {
        "method": "GET",
        "scheme": "https",
        "host": "api.example.com",
        "port": null,
        "path": "/users",
        "query": null,
        "headers": [["Authorization", "Bearer token"]],
        "body": ""
      },
      "response": {
        "mode": "blocking",
        "status": 200,
        "headers": [["Content-Type", "application/json"]],
        "body": "{\"users\": []}"
      }
    },
    {
      "request": { ... },
      "response": {
        "mode": "streaming",
        "status": 200,
        "headers": [["Content-Type", "text/event-stream"]],
        "chunks": [
          {"data": "data: Hello", "delay_ms": 50},
          {"data": "data: world", "delay_ms": 50}
        ]
      }
    }
  ]
}
```

You can edit these files manually to:
- Modify responses for edge case testing
- Adjust timing for streaming responses
- Add new recordings without making real requests

### Recorder API

- `recorder.start(mode, matching)` - Create a new recorder
- `recorder.stop(recorder)` - Save recordings (Record mode) and cleanup
- `recorder.is_record_mode(recorder)` - Check if in Record mode
- `recorder.add_recording(recorder, recording)` - Manually add a recording
- `recorder.find_recording(recorder, request)` - Find matching recording
- `recorder.get_recordings(recorder)` - Get all recordings

- `recorder.Record(directory)` - Record real requests to directory
- `recorder.Playback(directory)` - Play back from directory
- `recorder.Passthrough` - No recording/playback

- `matching.match_url_only()` - Default matching (method + URL)
- `matching.MatchingConfig(...)` - Custom matching rules

## API Reference

### Types

#### `ClientRequest`

HTTP request configuration with all components:
- `method`: HTTP method (GET, POST, etc.)
- `scheme`: Protocol (HTTP or HTTPS)
- `host`: Server hostname
- `port`: Optional port number (defaults to 80 for HTTP, 443 for HTTPS)
- `path`: Request path
- `query`: Optional query string
- `headers`: List of header name-value pairs
- `body`: Request body as string
- `timeout`: Optional timeout in milliseconds (defaults to 30000ms)

#### `RequestId`

Opaque identifier for an active message-based stream. Returned from `stream_messages()` and included in all `StreamMessage` variants. Use this to:
- Track multiple concurrent streams
- Cancel specific streams
- Associate messages with the correct request

#### `StreamMessage`

Union type for message-based streaming. Most variants include the `RequestId`:

- `StreamStart(request_id, headers)` - Stream started, initial headers received
- `Chunk(request_id, data)` - Data chunk received (BitArray)
- `StreamEnd(request_id, headers)` - Stream completed, trailing headers received
- `StreamError(request_id, reason)` - Stream failed with error message
- `DecodeError(reason)` - FFI corruption (should be reported as a bug)

**About DecodeError:**

`DecodeError` is a rare error indicating the Erlang→Gleam FFI boundary received
a malformed message from `httpc`. This is **not a normal HTTP error** - it means:
- Erlang/OTP version incompatibility with this library
- Memory corruption or other serious runtime issue
- A bug in this library's FFI code

Unlike other variants, `DecodeError` does not include a `RequestId` because the
request ID itself could not be decoded. If you see this error, please report it
as a bug with the full error message at https://github.com/TrustBound/dream/issues

### Client Configuration (Builder Pattern)

- `client.new` - Create default request configuration
- `client.method(req, method)` - Set HTTP method (GET, POST, etc.)
- `client.scheme(req, scheme)` - Set protocol (HTTP or HTTPS)
- `client.host(req, host)` - Set hostname (required)
- `client.port(req, port)` - Set port number (optional, defaults to 80/443)
- `client.path(req, path)` - Set request path
- `client.query(req, query)` - Set query string
- `client.body(req, body)` - Set request body
- `client.timeout(req, timeout_ms)` - Set request timeout in milliseconds
- `client.add_header(req, name, value)` - Add a single header
- `client.headers(req, headers)` - Replace all headers at once

### Request Execution

#### Blocking Mode

- `client.send(req) -> Result(String, String)`
  - Returns complete response body as string
  - Blocks until entire response received
  - Returns `Ok(body)` on success or `Error(msg)` on failure

#### Yielder Streaming Mode

- `client.stream_yielder(req) -> yielder.Yielder(Result(bytes_tree.BytesTree, String))`
  - Returns yielder that produces `Result` values for each chunk
  - `Ok(chunk)` - Successful chunk, more may follow
  - `Error(reason)` - Terminal error, stream is done
  - Normal completion: Yielder returns `Done` (no error yielded)
  - Pull-based: blocks while waiting for next chunk
  - Use with `yielder.each()`, `yielder.fold()`, `yielder.to_list()`, etc.
  - **Not suitable for OTP actors with concurrent operations**

#### Message-Based Streaming Mode

- `client.stream_messages(req) -> Result(RequestId, String)`
  - Starts stream and returns `RequestId` immediately
  - Push-based: messages sent to your process mailbox automatically
  - Non-blocking and fully OTP-compatible
  - Returns `Ok(request_id)` if stream started, `Error(msg)` if failed

- `client.select_stream_messages(selector, mapper) -> Selector(msg)`
  - Integrates stream messages into an OTP selector
  - `mapper` converts `StreamMessage` to your actor's message type
  - Use in `actor.Spec` init function to build your selector

- `client.cancel_stream(request_id) -> Nil`
  - Cancels an active message-based stream
  - No more messages will arrive for this `RequestId`
  - Safe to call multiple times on same ID

## Error Handling

All execution modes use `Result` types to force explicit error handling:

### Blocking and Message Start Errors

```gleam
import dream_http_client/client.{send}
import gleam/io.{println_error}

case send(request) {
  Ok(body) -> process_response(body)
  Error(msg) -> {
    // Common errors:
    // - Connection refused
    // - DNS resolution failed
    // - Invalid URL
    // - Timeout
    println_error("Request failed: " <> msg)
  }
}
```

### Streaming Errors

For message-based streaming, errors arrive as `StreamError` messages:

```gleam
import dream_http_client/client.{StreamError}

HttpStream(StreamError(req_id, reason)) -> {
  // Handle mid-stream errors:
  // - Network interruption
  // - Server closed connection
  // - Timeout
  log_error(req_id, reason)
  cleanup_stream(state, req_id)
}
```

### Best Practices

1. **Always handle `Error` cases** - Network operations can fail
2. **Set appropriate timeouts** - Use `client.timeout()` to configure request timeouts (default: 30s)
3. **Handle yielder errors** - `stream_yielder()` produces `Result` values, check each one
4. **Cancel streams when done** - Free resources with `cancel_stream()`
5. **Track active streams** - Use a `Dict(RequestId, State)` in actors
6. **Handle StreamError and DecodeError** - Network can fail mid-stream, FFI can corrupt
7. **Test error paths** - Simulate failures in tests with slow/error endpoints

## Design Principles

This module follows the same quality standards as [Dream](https://github.com/TrustBound/dream):

- **No nested cases** - Clear, flat control flow throughout
- **No anonymous functions** - All functions are named for clarity
- **Builder pattern** - Consistent, composable request configuration
- **Type safety** - `Result` types force error handling at compile time
- **OTP-first design** - Message-based API designed for supervision trees
- **Comprehensive testing** - Unit tests (no network) + integration tests (real HTTP)
- **Battle-tested foundation** - Built on Erlang's production-proven `httpc`

## About Dream

This module was originally built for the [Dream](https://github.com/TrustBound/dream) web toolkit, but it's completely standalone and can be used in any Gleam project. It follows Dream's design principles and will be maintained as part of the Dream ecosystem.

## License

MIT License - see LICENSE file for details.
