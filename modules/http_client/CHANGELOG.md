# Changelog

All notable changes to `dream_http_client` will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
  - Use builder pattern (`client.new` + setters) and getter functions instead
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
