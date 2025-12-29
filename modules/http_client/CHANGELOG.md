# Changelog

All notable changes to `dream_http_client` will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 4.0.0 - 2025-12-29

### Breaking Changes

- **Recorder API redesigned**: `recorder.start(mode, matching_config)` replaced by a builder API:
  - `recorder.new() |> directory(dir) |> mode("record"|"playback"|"passthrough") |> start()` (import `dream_http_client/recorder.{directory, mode, start}`)
- **Client request builder updated**:
  - `client.new` is now `client.new()` (function) for consistency with other builders
- **Matching API redesigned**:
  - Removed `matching.MatchingConfig`, `matching.match_url_only()`, and signature/match helpers
  - Added `matching.MatchKey` and `matching.request_key(method:, url:, headers:, body:)`
- **Ambiguous playback now errors**: if multiple recordings share the same computed key, lookup returns an error (indicates the key/transformer is too coarse).
- `recorder.find_recording(...)` now returns `Result(Option(Recording), String)` to surface ambiguity errors.

### Added

- **Custom match keys** via `recorder.key(...)` (any `RecordedRequest -> String`).
- **Request transformer hook** via `recorder.request_transformer(...)` to normalize/scrub requests before keying and persistence.
- **Response transformer hook** via `recorder.response_transformer(...)` to scrub recorded responses before they are written to disk (Record mode only).

### Changed

- Recording filenames now include both a **key hash** and a **content hash** to avoid overwriting when multiple recordings share a key:
  - `{method}_{host}_{path}_{key_hash}_{content_hash}.json`
- Recorded responses now persist more metadata for safer fixtures:
  - **Blocking** recordings persist the response **status code** and **headers**
  - **Streaming** recordings persist response **headers** captured from `stream_start` (and trailing headers when available)

## 3.0.1 - 2025-12-10

### Added

- **Per-File Recording Strategy** - Recordings now stored in individual files with format `{method}_{host}_{path}_{hash}.json`
- Human-readable filenames with hash suffix for uniqueness
- O(1) write performance (no more read-modify-write cycles)
- Concurrent test recording support (no file contention)
- `gleam_crypto` dependency for generating unique filename hashes

### Changed

- **Internal:** `storage.save_recordings()` and `storage.save_recording_immediately()` now require a `matching_config` parameter (not user-facing - users interact with `recorder` module)
- Recordings are now organized as individual files instead of a single `recordings.json`
- Better organization for large test suites - each recording is version controllable

### Fixed

- Eliminated O(n) read-modify-write performance issue
- Concurrent tests can now record safely without file contention

**Note:** Backward compatible - existing recordings still load correctly. User-facing `recorder` API unchanged.

## 3.0.0 - 2025-12-09

### Breaking Changes

**Redesigned Streaming API**

- Removed `stream_messages()` - replaced with `start_stream()` using callback-based API
- Removed `select_stream_messages()` - no longer needed with new design
- Streaming now uses dedicated processes with callbacks instead of selector boilerplate
- `StreamMessage`, `RequestId` types still exist but are internal implementation details

**New Streaming Functions:**

- `start_stream(request) -> Result(StreamHandle, String)` - Spawn stream with callbacks
- `await_stream(handle)` - Wait for stream completion
- `cancel_stream_handle(handle)` - Cancel running stream
- `is_stream_active(handle)` - Check if stream still running

**Builder Functions for Callbacks:**

- `on_stream_start(callback)` - Called when stream starts (optional)
- `on_stream_chunk(callback)` - Called for each chunk (optional)
- `on_stream_end(callback)` - Called when stream completes (optional)
- `on_stream_error(callback)` - Called on error (optional)

**Header Type Added**

- Introduced `Header` type for type-safe header handling
- `Header(name: String, value: String)` replaces raw tuples throughout
- `get_headers()` now returns `List(Header)` instead of `List(#(String, String))`
- `StreamStart` and `StreamEnd` use `List(Header)` for headers
- `add_header(name, value)` still takes strings (builds Header internally)

### Changed

**Recordings Now Saved Immediately**

- Recordings are now saved to disk immediately when captured, rather than waiting for `stop()` to be called
- `recorder.stop()` is now optional - it only performs cleanup of the recorder process
- This ensures recordings are never lost even if the process crashes or `stop()` is not called
- Added `storage.save_recording_immediately()` function for immediate persistence

**Performance Tradeoff:** Immediate saving uses a read-modify-write approach (O(n) where n is existing recordings), prioritizing reliability over performance. This is suitable for typical use cases (record once, playback often). If you need high-performance recording, please create an issue at https://github.com/TrustBound/dream/issues.

### Documentation

- Added comprehensive hexdocs for all public functions and types across all modules
- Enhanced Erlang FFI documentation with detailed parameter and return value descriptions
- Improved examples and usage notes throughout the codebase
- Added tested code snippets following dream_ets pattern

### Migration Guide

**From 2.x stream_messages() to 3.0 start_stream():**

Before (2.x):

```gleam
let selector = process.new_selector()
  |> client.select_stream_messages(HttpStream)

let assert Ok(req_id) = client.stream_messages(request)

// Manual selector receive loop...
```

After (3.0):

```gleam
let assert Ok(stream) = client.new()
  |> client.on_stream_chunk(fn(data) { process_chunk(data) })
  |> client.start_stream()

client.await_stream(stream)  // Optional
```

**Header type:**

Before (2.x):

```gleam
let headers: List(#(String, String)) = client.get_headers(req)
```

After (3.0):

```gleam
let headers: List(Header) = client.get_headers(req)
// Access with header.name and header.value
```

## 2.1.1 - 2025-11-29

### Fixed

**Critical: Streaming Recording Now Actually Works**

- Fixed broken streaming recording in `stream_yielder()` - was only doing playback, not recording
- Fixed missing recorder integration in `stream_messages()` - had no recording implementation at all
- Fixed `RequestId` type safety by eliminating `Dynamic` type leak - now wraps `String` properly
- Fixed ETS-based bidirectional mapping for stream cancellation in recorded streams
- Streaming recording now captures chunks and timing delays as they arrive, not just on completion

**Error Handling and Code Quality**

- Eliminated all error discarding with underscore patterns (`Error(_)`, `Error(_error)`) throughout the module
- Added explicit error logging with `io.println_error()` to surface previously-silent failures
- Flattened deeply nested case expressions into named helper functions for maintainability
- Improved error messages and documentation for debugging

**Documentation**

- Added comprehensive documentation for `encode_recording_file()` and `decode_recording_file()`
- Updated `ClientRequest` module docs to reference current public API entrypoints
- Clarified expected error logging in tests (connection failures and timeouts are intentional)

### Changed

- Recording storage moved from `/tmp` to `build/` directory (cleaned by `gleam clean`)
- Added `dream_ets` dependency to project for ETS state management
- Internal variables renamed for clarity throughout (e.g., `req` → `client_request`, `rec` → `recorder_instance`)

### Technical Notes

- The streaming recording implementation was fundamentally broken in 2.1.0 - tests were rigged by manually creating `Recording` objects instead of making real HTTP requests
- Users who tried to record streaming requests in 2.1.0 got empty recordings
- This release actually implements what 2.1.0 claimed to provide
- `RequestId` strings are generated from httpc refs (e.g., `#Ref<0.123.456>`) - unique per VM but not stable across restarts
- Recording only adds overhead when recorder is attached in Record mode - zero cost otherwise
- ETS tables (`dream_http_client_stream_recorders`, `dream_http_client_ref_mapping`) are created on-demand

## 2.1.0 - 2025-11-28

### Added

**HTTP Request/Response Recording and Playback**

- Added recording and playback capabilities for HTTP requests and responses
- Added `recorder` module with `Record`, `Playback`, and `Passthrough` modes
- Added `matching` module for customizable request matching strategies
- Added `recording` module with `RecordedRequest`, `RecordedResponse`, and `Recording` types
- Added `storage` module for persisting and loading recordings from JSON files
- Supports both blocking and streaming requests
- Recordings preserve chunk timing for realistic streaming playback
- Added `client.recorder()` builder function to attach recorders to requests

**Request Inspection (Getter Functions)**

- Made `ClientRequest` type opaque to ensure API stability
- Added getter functions for all request properties:
  - `get_method()` - Get the HTTP method
  - `get_scheme()` - Get the URI scheme (HTTP/HTTPS)
  - `get_host()` - Get the hostname
  - `get_port()` - Get the optional port number
  - `get_path()` - Get the request path
  - `get_query()` - Get the optional query string
  - `get_headers()` - Get the headers list
  - `get_body()` - Get the request body
  - `get_timeout()` - Get the optional timeout
  - `get_recorder()` - Get the optional recorder
- Enables request inspection for logging, testing, and middleware

### Changed

- **Breaking (for direct constructor usage only)**: `ClientRequest` type is now opaque
  - The constructor can no longer be used directly for pattern matching
- Use builder pattern (`client.new()` + setters) and getter functions instead
  - This change only affects code that was directly constructing or pattern matching `ClientRequest`
  - The builder pattern (documented public API) remains unchanged and non-breaking

### Technical Notes

- Added dependencies: `gleam_json`, `simplifile`, `gleam_otp` for recording functionality
- Internal function `get_timeout` renamed to `resolve_timeout` to avoid naming conflict with public getter

## 2.0.0 - 2025-11-24

### 🚨 Breaking Changes

**Module Consolidation**

- **BREAKING**: Consolidated `fetch` and `stream` modules into unified `client` module
  - Migration: Change `import dream_http_client/fetch` to `import dream_http_client/client`
  - Migration: Change `fetch.request()` to `client.send()`
  - Migration: Change `import dream_http_client/stream` to `import dream_http_client/client`
  - Migration: Change `stream.stream_request()` to `client.stream_yielder()`

**Stream Yielder API Change**

- **BREAKING**: `stream_yielder()` now returns `yielder.Yielder(Result(BytesTree, String))` instead of `yielder.Yielder(BytesTree)`
  - Migration: Wrap chunk processing in `case` to handle `Ok(chunk)` and `Error(reason)`
  - Reason: Errors were being silently discarded; now properly surfaced to callers

**StreamMessage Type Change**

- **BREAKING**: Added `DecodeError(reason: String)` variant to `StreamMessage` type
  - Migration: Update pattern matches to handle `DecodeError` or use catch-all pattern
  - Reason: FFI corruption now returns explicit error instead of faking RequestId

### Added

**Message-Based Streaming**

- Added `stream_messages()` for OTP actor integration
- Added `StreamMessage` type with `StreamStart`, `Chunk`, `StreamEnd`, `StreamError`, and `DecodeError` variants
- Added `RequestId` opaque type for stream identification in concurrent scenarios
- Added `select_stream_messages()` for OTP selector integration
- Added `cancel_stream()` for graceful stream cancellation

**Configuration**

- Added configurable request timeout via `client.timeout(request, milliseconds)` builder
- Default timeout is 600 seconds (10 minutes) if not specified
- Added `MOCK_SERVER_PORT` environment variable for configurable test port

**Testing**

- All tests now use `dream_mock_server` instead of external dependencies like httpbin.org
- Added comprehensive error handling tests
- Added unit tests for malformed header handling
- Added unit test for `timeout()` builder function
- Added regression tests for `stream_yielder` completion behavior

### Changed

**Error Handling**

- All errors now include underlying decode errors instead of being discarded
- Improved error messages to be actionable and user-friendly
- Removed all `panic` calls in favor of graceful error returns
- All timeout values now configurable (previously hardcoded 600 seconds)

**FFI Boundary**

- Refactored FFI boundary: Erlang now handles all raw `httpc` message parsing and normalization
- Gleam client receives clean, simplified data structures from FFI
- Better separation of concerns between Erlang (raw parsing) and Gleam (type-safe API)

**Code Quality**

- Eliminated all anonymous functions and closures (coding standards compliance)
- Flattened all nested `case` expressions (coding standards compliance)
- Comprehensive error handling throughout codebase
- No more error discarding with `Error(_)` or `let _ = error` patterns

### Fixed

- Fixed `send()` hanging on non-chunked responses by implementing separate synchronous `httpc` mode
- Fixed `stream_yielder()` incorrectly signaling errors for normal stream completion
- Fixed `stream_yielder()` and `stream_messages()` to correctly include port in URLs
- Fixed message routing in streaming mode to send to correct process
- Fixed `decode_headers()` error handling to propagate failures instead of hiding them
- Fixed `RequestId` handling during FFI corruption (now returns `DecodeError` variant)
- Fixed streaming tests not filtering messages by `RequestId`, causing cross-contamination

### Acknowledgements

Special thanks to **Louis Pilfold** for bringing to our attention that the HTTP client did not support message-based streaming for OTP actors, which led to the comprehensive overhaul in this release.

## 1.0.2 - 2025-11-21

### Changed

- Added HexDocs documentation badge to README

## 1.0.1 - 2025-11-22

### Fixed

- Fixed logo display on hex.pm by using full GitHub URL
- Added Dream logo to README

## 1.0.0 - 2025-11-21

### Added

- Initial stable release
- Builder pattern for HTTP request configuration
- `fetch.request()` - Non-streaming HTTP requests
- `stream.stream_request()` - Streaming HTTP requests with yielder
- Support for all HTTP methods (GET, POST, PUT, DELETE, etc.)
- HTTPS support via Erlang's httpc
- Header management (add, replace)
- Query string support
- Request body support
