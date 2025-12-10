# dream_http_client 3.0.0 Release Notes

**Release Date:** December 9, 2025

dream_http_client 3.0.0 redesigns the streaming API with process isolation and callbacks, adds a Header type for type safety, and includes automatic recording saves.

## Key Highlights

- 🔄 **Redesigned Streaming API** - Process-based callbacks replace selector boilerplate (BREAKING)
- 🏷️ **Header Type** - Type-safe headers throughout the module (BREAKING)
- 💾 **Auto-Save Recordings** - Recordings saved immediately when captured
- 📚 **Enhanced Documentation** - World-class hexdocs and tested snippets

## What's Changed

### Redesigned Streaming API (BREAKING)

The message-based streaming API has been completely redesigned for better ergonomics and BEAM best practices.

**Before (2.x):**
```gleam
let selector = process.new_selector()
  |> client.select_stream_messages(HttpStream)

let assert Ok(req_id) = client.stream_messages(request)

// Manual selector receive loop with 40+ lines of boilerplate
```

**After (3.0):**
```gleam
let assert Ok(stream) = client.new
  |> client.on_stream_chunk(fn(data) { io.print(data) })
  |> client.start_stream()

client.await_stream(stream)  // Wait for completion
```

**What changed:**
- Removed `stream_messages()` and `select_stream_messages()` (now internal)
- Added `start_stream()` - spawns dedicated process with callbacks
- Added `await_stream()`, `cancel_stream_handle()`, `is_stream_active()`
- Callbacks run in isolated process - cleaner mailbox separation
- No selector boilerplate required

### Header Type Added (BREAKING)

Added `Header` type for type-safe header handling throughout the module.

**Changes:**
- `get_headers()` returns `List(Header)` instead of `List(#(String, String))`
- `StreamStart` and `StreamEnd` use `List(Header)` for headers
- `add_header(name, value)` still takes strings (ergonomic builder pattern)

**Migration:**
```gleam
// Before:
case headers {
  [#(name, value), ..] -> ...
}

// After:
case headers {
  [Header(name, value), ..] -> ...
}
```

### Recordings Now Saved Immediately

Recordings are now saved to disk immediately when captured, rather than waiting for `stop()` to be called. This ensures recordings are never lost even if:

- The process crashes unexpectedly
- `stop()` is forgotten or not called
- The application terminates without cleanup

**Before (2.1.1):**

```gleam
let assert Ok(rec) = recorder.start(
  mode: recorder.Record(directory: "mocks"),
  matching: matching.match_url_only(),
)

client.new |> client.recorder(rec) |> client.send()
// ... more requests ...

recorder.stop(rec)  // Required! Without this, recordings lost
```

**After (2.2.0):**

```gleam
let assert Ok(rec) = recorder.start(
  mode: recorder.Record(directory: "mocks"),
  matching: matching.match_url_only(),
)

client.new |> client.recorder(rec) |> client.send()
// ... more requests ...

// stop() is optional - recordings already saved!
recorder.stop(rec)  // Just cleanup, not required
```

### Performance Tradeoff

This implementation uses a read-modify-write approach (O(n) file I/O where n is existing recordings), prioritizing reliability over performance. This is suitable for typical use cases (record once, playback often).

If you need high-performance recording with deferred saves or delta files, please create an issue at https://github.com/TrustBound/dream/issues.

### Documentation Improvements

Added comprehensive hexdocs for all public functions and types:

- **storage.gleam**: All 3 public functions documented with examples
- **recorder.gleam**: All types and functions documented with usage patterns
- **recording.gleam**: All types and encoding/decoding functions documented
- **matching.gleam**: All matching configuration functions documented
- **client.gleam**: Enhanced RequestId type documentation
- **internal.gleam**: All FFI functions documented with Erlang details
- **dream_httpc_shim.erl**: All exported Erlang functions documented with EDoc

## Upgrading

Update your dependencies:

```toml
[dependencies]
dream_http_client = ">= 3.0.0 and < 4.0.0"
```

Then run:

```bash
gleam deps download
```

### Migration Notes

**No Breaking Changes**

- `stop()` still works exactly as before
- All existing code continues to work without modification
- The only change is that `stop()` is now optional for saving recordings

**If you were relying on `stop()` to save recordings:**

You can now remove `stop()` calls if you only needed them for saving. However, it's still recommended to call `stop()` for proper resource cleanup in long-running applications.

## Internal Changes

- Added `storage.save_recording_immediately()` function
- Modified `recorder.add_recording()` to save immediately in Record mode
- Simplified `recorder.stop()` to only perform cleanup
- Enhanced error handling to log save failures without crashing

## Testing

All 112 tests pass:

```
112 passed, no failures
```

New tests added:

- `add_recording_in_record_mode_saves_immediately_test()` - Verifies immediate saving
- `save_recording_immediately_appends_to_existing_test()` - Verifies append behavior

## Documentation

- [dream_http_client](https://hexdocs.pm/dream_http_client) - v2.2.0
- [Full Documentation](https://github.com/TrustBound/dream/tree/main/modules/http_client)

## Community

- 📖 [Full Documentation](https://github.com/TrustBound/dream/tree/main/modules/http_client)
- 💬 [Discussions](https://github.com/TrustBound/dream/discussions)
- 🐛 [Report Issues](https://github.com/TrustBound/dream/issues)
- 🤝 [Contributing Guide](https://github.com/TrustBound/dream/blob/main/CONTRIBUTING.md)

---

**Full Changelog:** [CHANGELOG.md](https://github.com/TrustBound/dream/blob/main/modules/http_client/CHANGELOG.md)
