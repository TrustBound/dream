# dream_http_client v5.1.1

**Release Date:** March 1, 2026

This patch release fixes a bug where stream error reasons from Erlang's `httpc`
could not be decoded as Gleam strings, causing error details to be silently lost
or replaced with generic messages like "Unknown stream error".

No API changes -- this is a fully transparent bug fix.

---

## Bug Fix: Stream error reason decoding

### The problem

Transport-level errors from `httpc` (connection refused, socket closed, DNS
failure, etc.) produce raw Erlang atoms or tuples as error reasons. These were
handled differently depending on the streaming path:

- **Pull-based (`stream_yielder`)**: Raw Erlang terms were passed through
  without formatting. `d.string` failed, and the error was silently replaced
  with "Unknown stream error".
- **Message-based (`start_stream`)**: `format_error` used
  `iolist_to_binary(io_lib:format("~p", [Reason]))` which can produce
  non-UTF-8 binary (Latin-1 bytes). Gleam's `d.string` validates UTF-8, so it
  rejected the binary with `DecodeError("String", "String", [])`.

In both cases, the actual error information (e.g., `econnrefused`,
`socket_closed_remotely`) was lost.

### Why previous tests didn't catch it

All streaming tests hit the mock server, which always returns valid HTTP
responses. Even the "error" tests (401, 500) produce the **complete HTTP
response** message path, where `format_complete_response_error` outputs pure
ASCII. The bug only fires on the **transport error** path
(`{http, {Ref, {error, Reason}}}`) -- connection failures, socket drops, DNS
errors -- which no mock server endpoint triggered.

### The fix

**Erlang side (belt):**

- Added `ensure_utf8_binary/1` helper that validates UTF-8, falls back to
  Latin-1 reinterpretation, then to `~w` (pure ASCII) as a last resort
- Updated all 5 error formatting functions to use it: `format_error`,
  `format_complete_response_error`, `format_exit_reason`, `to_binary`,
  `ref_to_string`
- Fixed `stream_owner_wait` and `stream_owner_next_message` to call
  `format_error(Reason)` on raw httpc error reasons instead of passing
  atoms/tuples through

**Gleam side (suspenders):**

- `decode_error_reason` in `client.gleam` now uses a three-tier fallback:
  try `d.string` -> try `d.bit_array` with `to_string` -> fall back to
  `string.inspect`
- `receive_next` in `internal.gleam` uses the same three-tier fallback

**New tests (9 tests, 177 total):**

| Error type | send | start_stream | stream_yielder |
|---|---|---|---|
| Connection refused | test | test | test |
| Connection drop mid-stream | -- | test | test |
| Non-UTF-8 body in HTTP error | test | test | test |
| Error string quality | -- | test | -- |

**New mock server endpoints:**

- `GET /stream/drop` -- sends 2 chunks then crashes to close the TCP socket
  (triggers `socket_closed_remotely`)
- `GET /non-utf8-error` -- returns HTTP 400 with a body containing invalid
  UTF-8 bytes (0xC0, 0xC1, 0xFE, 0xFF)

---

## Files changed

- `modules/http_client/src/dream_http_client/dream_httpc_shim.erl` -- added
  `ensure_utf8_binary/1`, updated error formatting, fixed raw reason passthrough
- `modules/http_client/src/dream_http_client/client.gleam` -- three-tier
  fallback in `decode_error_reason`
- `modules/http_client/src/dream_http_client/internal.gleam` -- three-tier
  fallback in `receive_next`
- `modules/http_client/test/stream_error_decode_test.gleam` -- 9 new tests
- `modules/mock_server/src/dream_mock_server/controllers/api_controller.gleam`
  -- added `/non-utf8-error` endpoint
- `modules/mock_server/src/dream_mock_server/controllers/stream_controller.gleam`
  -- added `/stream/drop` endpoint
- `modules/mock_server/src/dream_mock_server/router.gleam` -- added routes
