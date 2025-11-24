# Dream 2.1.0 Release Notes

**Release Date:** November 24, 2025

Dream 2.1.0 introduces the new `dream_mock_server` module for testing HTTP clients and a major overhaul of `dream_http_client` with message-based streaming support, making it fully compatible with OTP actors and concurrent operations.

## What's New

### 🆕 dream_mock_server 1.0.0

A general-purpose HTTP mock server for testing HTTP clients without external dependencies. Provides both streaming and non-streaming endpoints with programmatic control.

**Key Features:**
- Programmatic control: `start(port)` and `stop(handle)` functions
- 10 non-streaming endpoints for various test scenarios
- 4 streaming endpoints for testing chunked responses
- Full Cucumber integration test suite
- Comprehensive HexDocs documentation

**Non-Streaming Endpoints:**
- `GET /` - Info page with endpoint documentation
- `GET /get` - Echo query parameters
- `POST /post` - Echo request body
- `GET /status/:code` - Return specified HTTP status code
- `GET /json` - Sample JSON response
- `GET /text` - Plain text response
- `GET /uuid` - Generate and return UUID
- `GET /large` - Large response (1MB) for memory testing
- `GET /empty` - Empty response body
- `GET /slow` - Delayed response (2s) for timeout testing

**Streaming Endpoints:**
- `GET /stream/fast` - 10 chunks at 100ms intervals
- `GET /stream/slow` - 5 chunks at 2s intervals
- `GET /stream/burst` - Random burst pattern (5-10 chunks, 100-500ms delays)
- `GET /stream/huge` - 100 chunks for memory/performance testing

**Example Usage:**
```gleam
import dream_mock_server/server

pub fn test_http_client() {
  let assert Ok(mock) = server.start(3004)
  
  // Make requests to localhost:3004
  let result = http_client.get("http://localhost:3004/json")
  
  server.stop(mock)
}
```

### 🚨 dream_http_client 2.0.0 - BREAKING CHANGES

Major overhaul with message-based streaming, OTP actor support, and comprehensive error handling improvements.

#### Breaking Change 1: Module Consolidation

The `fetch` and `stream` modules have been consolidated into a unified `client` module.

**Migration:**
```gleam
// Before (v1.x)
import dream_http_client/fetch
import dream_http_client/stream

let body = client.new
  |> client.host("api.example.com")
  |> fetch.request()

let chunks = client.new
  |> client.host("cdn.example.com")
  |> stream.stream_request()

// After (v2.0)
import dream_http_client/client

let body = client.new
  |> client.host("api.example.com")
  |> client.send()

let chunks = client.new
  |> client.host("cdn.example.com")
  |> client.stream_yielder()
```

#### Breaking Change 2: stream_yielder() Return Type

The `stream_yielder()` function now returns `Result` values to properly surface errors.

**Migration:**
```gleam
// Before (v1.x)
client.new
  |> host("api.example.com")
  |> stream.stream_request()
  |> yielder.each(fn(chunk) {
    process(chunk)
  })

// After (v2.0)
client.new
  |> host("api.example.com")
  |> client.stream_yielder()
  |> yielder.each(fn(result) {
    case result {
      Ok(chunk) -> process(chunk)
      Error(reason) -> handle_error(reason)
    }
  })
```

#### Breaking Change 3: StreamMessage Type

Added `DecodeError` variant to `StreamMessage` for explicit FFI corruption handling.

**Migration:**
```gleam
// If you pattern match on StreamMessage, add DecodeError handling:
case msg {
  StreamStart(req_id, headers) -> ...
  Chunk(req_id, data) -> ...
  StreamEnd(req_id, headers) -> ...
  StreamError(req_id, reason) -> ...
  DecodeError(reason) -> ...  // NEW - handle FFI corruption
}

// Or use a catch-all:
case msg {
  Chunk(req_id, data) -> process(data)
  _ -> continue(state)
}
```

## New Features

### Message-Based Streaming (dream_http_client 2.0.0)

Added full OTP actor support for concurrent HTTP streams.

**New API:**
- `stream_messages()` - Start a message-based stream, returns `RequestId`
- `StreamMessage` type - Stream lifecycle messages sent to your mailbox
- `select_stream_messages()` - Integrate with OTP selectors
- `cancel_stream()` - Cancel active streams

**Example:**
```gleam
import dream_http_client/client.{
  type StreamMessage, Chunk, StreamEnd, StreamError, StreamStart,
  select_stream_messages
}
import gleam/otp/actor.{continue}
import gleam/erlang/process.{new_selector}

pub type Message {
  HttpStream(StreamMessage)
}

fn init_selector() {
  new_selector()
  |> select_stream_messages(HttpStream)
}

fn handle_message(msg: Message, state: State) {
  case msg {
    HttpStream(Chunk(req_id, data)) -> process_chunk(data, state)
    HttpStream(StreamEnd(req_id, _)) -> cleanup(req_id, state)
    HttpStream(StreamError(req_id, reason)) -> handle_error(state)
    HttpStream(StreamStart(_, _)) -> continue(state)
    HttpStream(DecodeError(reason)) -> log_corruption(reason, state)
  }
}
```

### Configurable Timeout (dream_http_client 2.0.0)

All HTTP requests now support configurable timeouts.

**Example:**
```gleam
import dream_http_client/client.{timeout}

client.new
  |> host("slow-api.example.com")
  |> timeout(5000)  // 5 second timeout
  |> send()
```

Default timeout is 600 seconds (10 minutes) if not specified.

### Improved Error Handling (dream_http_client 2.0.0)

**All errors now include full context:**
- No more discarded errors (`Error(_)` patterns eliminated)
- Decode errors include underlying reasons
- All error messages are actionable and user-friendly
- No `panic` calls - all errors return gracefully

**Before:**
```gleam
// Errors were silently discarded or returned as generic messages
Error("Request failed")
```

**After:**
```gleam
// Errors include full context
Error("Failed to decode headers: Expected string, found integer at position 2")
Error("Stream failed: Connection timeout after 30000ms")
```

## Documentation

### New Governance Files

- `CONTRIBUTING.md` - Quick start guide for contributors
- `CODE_OF_CONDUCT.md` - Community standards (Contributor Covenant 2.1)
- `SECURITY.md` - Security policy clarifying Dream's responsibilities as a library
- GitHub issue templates (bug reports, feature requests)
- GitHub pull request template

### Documentation Improvements

- Moved `TESTING.md` to `docs/contributing/testing.md`
- Updated architecture docs with correct `dream_http_client` API
- Added "About Dream" section explaining TrustBound's role
- All `dream_http_client` examples updated to use new API

## Bug Fixes

### dream_http_client 2.0.0

- **Fixed `send()` for non-streaming requests**: Now uses synchronous `httpc` mode. Previously used streaming mode which couldn't handle `Content-Length` responses
- **Fixed URL port handling**: `stream_yielder()` and `stream_messages()` now correctly include port in URLs
- **Fixed message routing**: Streaming messages now sent to correct process
- **Fixed header decoding**: Errors propagate instead of being hidden
- **Fixed RequestId handling**: FFI corruption returns `DecodeError` variant instead of crashing

## Testing

### dream_http_client 2.0.0

- All tests now use `dream_mock_server` instead of external dependencies
- Configurable test port via `MOCK_SERVER_PORT` environment variable
- Added unit tests for malformed header handling
- Added unit test for `timeout()` builder function

### dream_mock_server 1.0.0

- Comprehensive Cucumber integration test suite
- Unit tests for port configuration and lifecycle
- Tests for multiple concurrent servers
- Tests for server restart and idempotent stop

## Internal Changes

### Refactored FFI Boundary (dream_http_client 2.0.0)

Erlang now handles all raw `httpc` message parsing and normalization:
- Erlang FFI performs pattern matching on raw messages
- Erlang normalizes headers (charlist to binary)
- Gleam receives clean, simplified data structures
- Clear separation of concerns between layers

### Code Quality (dream_http_client 2.0.0)

- Flattened all nested `case` expressions
- Extracted all anonymous functions to named helpers
- Consistent error handling patterns throughout
- Comprehensive inline documentation

## Upgrading

Update your dependencies:

```toml
[dependencies]
dream = ">= 2.1.0 and < 3.0.0"
dream_http_client = ">= 2.0.0 and < 3.0.0"

[dev-dependencies]
dream_mock_server = ">= 1.0.0 and < 2.0.0"
```

Then run:
```bash
gleam deps download
```

### Migration Checklist

1. ✅ Update imports: `dream_http_client/fetch` → `dream_http_client/client`
2. ✅ Update imports: `dream_http_client/stream` → `dream_http_client/client`
3. ✅ Rename function calls: `fetch.request()` → `client.send()`
4. ✅ Rename function calls: `stream.stream_request()` → `client.stream_yielder()`
5. ✅ Update `stream_yielder()` usage to handle `Result` type
6. ✅ Add `DecodeError` handling to `StreamMessage` pattern matches (or use catch-all)
7. ✅ Consider using `stream_messages()` for OTP actors with concurrent streams
8. ✅ Replace external mock server dependencies with `dream_mock_server`
9. ✅ Run `gleam test` to verify all tests pass

## Acknowledgements

Special thanks to **Louis Pilfold** for bringing to our attention that the HTTP client did not support message-based streaming for OTP actors. This feedback led to the comprehensive overhaul of `dream_http_client` in this release, making it fully compatible with OTP patterns and concurrent operations.

## Documentation

All packages are available with updated documentation on HexDocs:
- [dream](https://hexdocs.pm/dream) - v2.1.0
- [dream_http_client](https://hexdocs.pm/dream_http_client) - v2.0.0
- [dream_mock_server](https://hexdocs.pm/dream_mock_server) - v1.0.0 (NEW)
- [dream_config](https://hexdocs.pm/dream_config)
- [dream_postgres](https://hexdocs.pm/dream_postgres)
- [dream_opensearch](https://hexdocs.pm/dream_opensearch)
- [dream_json](https://hexdocs.pm/dream_json)
- [dream_ets](https://hexdocs.pm/dream_ets)

## Community

- 📖 [Full Documentation](https://github.com/TrustBound/dream/tree/main/docs)
- 💬 [Discussions](https://github.com/TrustBound/dream/discussions)
- 🐛 [Report Issues](https://github.com/TrustBound/dream/issues)
- 🤝 [Contributing Guide](https://github.com/TrustBound/dream/blob/main/CONTRIBUTING.md)

---

**Full Changelog:** [CHANGELOG.md](https://github.com/TrustBound/dream/blob/main/CHANGELOG.md)

**Migration Guide:** See the "Breaking Changes" section above for detailed migration instructions.

