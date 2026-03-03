# dream_http_client v5.1.2

**Release Date:** March 3, 2026

This patch release fixes a bug where query parameters set via `.query()` were
silently dropped from outgoing HTTP requests across all three execution modes.

No API changes -- this is a fully transparent bug fix.

---

## Bug Fix: Query parameters dropped from URLs

### The problem

The `query()` builder correctly stored the query string on the `ClientRequest`,
and `to_http_request` correctly copied it to the `Request.query` field. But the
final URL assembly step dropped it:

- **`build_url` in `client.gleam`** constructed the URL from scheme, host, port,
  and path — but never appended `?query`. This affected `send()` and
  `start_stream()`.
- **`start_httpc_stream` in `internal.gleam`** had its own independent URL
  construction that also omitted the query string. This affected
  `stream_yielder()`.

Any caller using `.query("key=value")` silently sent requests without query
parameters. The server never received them.

### Why previous tests didn't catch it

All existing tests hit mock server endpoints that don't vary by query string
(`/text`, `/stream/fast`, etc.), so the absence of query parameters had no
observable effect. The mock server's `GET /get` endpoint was documented as
echoing query parameters, but the implementation only echoed the path — so even
tests using that endpoint couldn't detect the bug (fixed in mock server v1.1.1).

### The fix

**`client.gleam` — `build_url`:**

Added a case expression on `request.query`:
- `Some(query)` → appends `"?" <> query` to the URL
- `None` → no change (preserves existing behavior)

**`internal.gleam` — `start_httpc_stream`:**

Same fix applied to the independent URL construction used by `stream_yielder()`.

### Regression tests (8 new tests, 185 total)

All assertions parse the mock server's JSON `query` field for exact matching
rather than substring checks.

| Test | Execution mode | What it verifies |
|---|---|---|
| `send_includes_query_params_in_request` | `send()` | Query arrives at server |
| `send_without_query_params_sends_empty_query` | `send()` | No query = empty string |
| `send_with_special_characters_in_query` | `send()` | URL-encoded chars arrive verbatim |
| `send_with_empty_query_string` | `send()` | Empty string edge case |
| `stream_yielder_includes_query_params_in_request` | `stream_yielder()` | Query arrives via yielder path |
| `start_stream_includes_query_params_in_request` | `start_stream()` | Query arrives via callback path |
| `send_with_query_and_recorder_record_mode_preserves_query` | `send()` + recorder | Server receives query; recording captures it |
| `send_with_query_and_recorder_playback_mode_matches_query` | `send()` + recorder | Record + playback round-trip with query |

---

## Files changed

- `modules/http_client/src/dream_http_client/client.gleam` — `build_url` now
  appends query string
- `modules/http_client/src/dream_http_client/internal.gleam` —
  `start_httpc_stream` now appends query string
- `modules/http_client/test/recorder_client_test.gleam` — 8 new regression
  tests
- `modules/mock_server/src/dream_mock_server/controllers/api_controller.gleam`
  — `GET /get` now passes `request.query` to the view
- `modules/mock_server/src/dream_mock_server/views/api_view.gleam` —
  `get_to_json` now includes `query` field in JSON response
