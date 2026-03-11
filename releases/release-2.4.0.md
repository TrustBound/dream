# Dream 2.4.0 Release Notes

**Release Date:** March 10, 2026

Dream 2.4.0 introduces native Server-Sent Events (SSE) support backed by dedicated OTP actors, fixing a critical bug where SSE streams would stall after a few events. The new `dream/servers/mist/sse` module follows the same stash-and-upgrade pattern as WebSockets, giving each SSE connection its own mailbox and eliminating TCP message contention.

## Key Highlights

- **Native SSE support** — `upgrade_to_sse` spawns a dedicated OTP actor per connection, replacing the broken chunked encoding approach
- **Builder-style event API** — `event`, `event_name`, `event_id`, `event_retry` for structured SSE events
- **No closures** — explicit `dependencies` parameter, consistent with Dream's WebSocket pattern
- **Deprecation of `sse_response`** — old function kept for compatibility but marked deprecated with migration guidance
- **Comprehensive testing** — unit tests, tested documentation snippets, and Cucumber integration tests
- **Full documentation** — new SSE guide, updated streaming API reference, example application

## What's New

### Native SSE Module: `dream/servers/mist/sse`

The new module provides Dream's SSE abstraction for the Mist server adapter. It upgrades an HTTP request to an SSE connection backed by a dedicated OTP actor, avoiding the stalling issues of chunked transfer encoding.

```gleam
import dream/servers/mist/sse

pub fn handle_events(request, _context, _services) {
  sse.upgrade_to_sse(
    request,
    dependencies: MyDeps,
    on_init: handle_init,
    on_message: handle_message,
  )
}
```

**New Types:**
- `sse.SSEConnection` — opaque handle to the SSE connection
- `sse.Event` — structured SSE event built with builder functions
- `sse.Action(state, message)` — controls the SSE actor lifecycle

**Event Builders:**

```gleam
sse.event("{\"count\": 42}")
|> sse.event_name("tick")
|> sse.event_id("42")
|> sse.event_retry(5000)
```

**Action Helpers:**
- `sse.continue_connection(state)` — keep the actor running
- `sse.continue_connection_with_selector(state, selector)` — keep running with a new selector
- `sse.stop_connection()` — shut down the actor

### SSE Example Application

Added `examples/sse/` with a complete ticker application:
- Real-time counter events streamed to connected clients
- Named events with IDs for client-side filtering and reconnection
- Cucumber/Gherkin integration tests using HTTPoison's async streaming
- Scenario verifying events stream continuously without stalling

### SSE Documentation

- New `docs/guides/sse.md` covering SSE vs WebSockets vs streaming, the full upgrade lifecycle, event builders, broadcasting with `Subject` and `broadcaster`, client-side `EventSource`, and testing
- Updated `docs/reference/streaming-api.md` with `upgrade_to_sse` API reference, event builder signatures, and action helper documentation
- Updated `docs/guides/streaming.md` to direct users to the new dedicated SSE guide

## Bug Fix

### SSE Streams Stalling After 2–3 Events

**Bug:** `response.sse_response` used `Stream(yielder)` which Mist converted to chunked transfer encoding. The yielder blocked in the mist handler process's mailbox, competing with TCP messages (ACKs, window updates). After 2–3 events the mailbox would back up and the stream would stall.

**Fix:** The new `sse.upgrade_to_sse` function calls Mist's native `server_sent_events` which spawns a dedicated OTP actor with its own mailbox. SSE events and TCP messages no longer contend for the same process, eliminating the stalling entirely.

## Deprecated

### `response.sse_response`

The `sse_response` function is deprecated. It remains available for backward compatibility but its doc comment now includes a deprecation warning directing users to `dream/servers/mist/sse.upgrade_to_sse`.

**Migration:** Replace `sse_response` with `upgrade_to_sse`:

```gleam
// Before (stalls after a few events)
import dream/http/response

pub fn handle_events(request, _context, _services) {
  response.sse_response(200, my_yielder, "text/event-stream")
}

// After (dedicated actor, no stalling)
import dream/servers/mist/sse

pub fn handle_events(request, _context, _services) {
  sse.upgrade_to_sse(
    request,
    dependencies: MyDeps,
    on_init: handle_init,
    on_message: handle_message,
  )
}
```

## Testing

- Unit tests for event builders and action wrappers in `test/dream/servers/mist/sse_test.gleam`
- Tested documentation snippets in `test/snippets/` ensuring all code examples from docs compile and run
- Cucumber integration tests in `examples/sse/` verifying:
  - Correct SSE response headers (`Content-Type: text/event-stream`)
  - Events stream with expected data payloads
  - Named events include `event:` and `id:` fields
  - Events do not stall (the original bug scenario)

## Upgrading

Update your dependencies:

```toml
[dependencies]
dream = ">= 2.4.0 and < 3.0.0"
```

Then run:

```bash
gleam deps download
```

### Migration Guide

**No breaking changes!** This release is fully backward compatible.

If you are currently using `sse_response`, we strongly recommend migrating to the new SSE module:

1. Import the SSE module:
   ```gleam
   import dream/servers/mist/sse
   ```

2. Define your message type and dependencies:
   ```gleam
   pub type MyMessage { Tick }
   pub type MyDeps { MyDeps }
   ```

3. Replace `sse_response` with `upgrade_to_sse`:
   ```gleam
   pub fn handle_events(request, _context, _services) {
     sse.upgrade_to_sse(
       request,
       dependencies: MyDeps,
       on_init: handle_init,
       on_message: handle_message,
     )
   }
   ```

4. See `examples/sse/` and `docs/guides/sse.md` for a complete walkthrough.

## Documentation

- [dream](https://hexdocs.pm/dream) - v2.4.0
- [SSE Guide](https://github.com/TrustBound/dream/blob/main/docs/guides/sse.md)
- [Streaming API Reference](https://github.com/TrustBound/dream/blob/main/docs/reference/streaming-api.md)

## Community

- [Full Documentation](https://github.com/TrustBound/dream/tree/main/docs)
- [Discussions](https://github.com/TrustBound/dream/discussions)
- [Report Issues](https://github.com/TrustBound/dream/issues)
- [Contributing Guide](https://github.com/TrustBound/dream/blob/main/CONTRIBUTING.md)

---

**Full Changelog:** [CHANGELOG.md](https://github.com/TrustBound/dream/blob/main/CHANGELOG.md)
