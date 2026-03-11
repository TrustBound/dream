# Dream 2.4.1 Release Notes

**Release Date:** March 11, 2026

This release fixes a bug where `upgrade_to_sse` discarded middleware-applied response headers (e.g., CORS), causing cross-origin SSE requests to fail.

## Key Highlights

- **SSE middleware header preservation**: CORS, security, and other middleware-applied headers now appear in the SSE response sent to the client
- **Middleware rejection guard**: If middleware returns a non-200 status, the SSE upgrade is not performed and the error response is returned to the client
- **Comprehensive integration tests**: 4 new integration test scenarios covering CORS headers, middleware stacking, rejection, and streaming continuity

## Fixed

### SSE upgrade discards middleware-applied response headers

Mist's `server_sent_events` sends HTTP headers to the TCP socket immediately during the call. Because `upgrade_to_sse` was calling `server_sent_events` inside the controller — before middleware had a chance to modify the response — any headers added by middleware (CORS, security headers, etc.) were silently discarded.

The fix introduces a **deferred upgrade** pattern:

1. The controller calls `upgrade_to_sse`, which stashes an **upgrade thunk** (a function that will perform the Mist SSE upgrade) instead of performing the upgrade immediately.
2. The middleware chain runs on the dummy response, adding CORS/security/other headers.
3. The handler checks for the stashed upgrade thunk after middleware completes. If found and the response status is 200, it extracts headers from the middleware-modified Dream response and passes them to the upgrade thunk.
4. The thunk calls `mist.server_sent_events` with an `initial_response` that includes all middleware-applied headers.

If middleware returns a non-200 status (e.g., 401 from an auth check), the upgrade thunk is not called and the error response is returned normally.

### Before (broken)

```
Controller -> upgrade_to_sse() -> Mist sends bare 200 headers immediately
Middleware -> adds CORS headers to dummy response (too late, already on wire)
Handler -> returns Mist response (CORS headers discarded)
```

### After (fixed)

```
Controller -> upgrade_to_sse() -> stashes upgrade thunk, returns dummy response
Middleware -> adds CORS headers to dummy response
Handler -> extracts headers from response, calls upgrade thunk with CORS headers
Mist -> sends 200 with CORS headers to client
```

## Added

- `upgrade_key` constant in `internal.gleam` for the deferred upgrade stash
- `extract_dream_headers` helper in `handler.gleam` to convert Dream headers to tuples
- `examples/sse/src/middleware.gleam` with CORS, rejection, and security-headers middleware
- 3 new SSE example routes: `/events/cors`, `/events/rejected`, `/events/stacked`
- 4 new integration test scenarios:
  - CORS middleware headers appear on SSE response
  - Multiple middleware headers all appear on SSE response
  - Middleware rejection prevents SSE upgrade
  - CORS middleware does not interfere with event streaming
- "Using Middleware with SSE" section in the SSE guide

## Upgrading

Update your dependencies:

```toml
[dependencies]
dream = ">= 2.4.1 and < 3.0.0"
```

Then run:

```bash
gleam deps download
```

## Documentation

- [dream](https://hexdocs.pm/dream) - v2.4.1

---
