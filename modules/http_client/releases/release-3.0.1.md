# dream_http_client 3.0.1 Release Notes

**Release Date:** December 10, 2025

dream_http_client 3.0.1 introduces per-file recording strategy for better performance, concurrency, and organization. This is a non-breaking enhancement - the user-facing `recorder` API remains unchanged.

## Key Highlights

- 📁 **Per-File Recording Strategy** - Individual files per recording instead of single file
- ⚡ **O(1) Write Performance** - No more read-modify-write cycles
- 🔄 **Concurrent Test Support** - No file contention between parallel tests
- 🗂️ **Better Organization** - Human-readable filenames with hash for uniqueness
- ✅ **Backward Compatible** - Existing recordings still load correctly

## What's Changed

### Per-File Recording Strategy

Recordings are now stored in individual files instead of a single `recordings.json` file.

**Filename Format:**
```
{method}_{host}_{path}_{hash}.json
```

**Examples:**
- `GET_api.example.com_users_a3f5b2.json`
- `POST_api.example.com_users_c7d8e9.json`
- `GET_localhost_text_f1a2b3.json`

**Benefits:**
- **O(1) write performance** - Just write one file, no read-modify-write cycle
- **Concurrent tests work** - No file contention between parallel tests
- **Granular control** - Version control, inspect, and modify individual recordings
- **Better organization** - Easier to manage large test suites
- **Human-readable** - Filenames show what endpoint they're for

**Before (3.0.0):**
```gleam
// Single file: mocks/recordings.json
storage.save_recordings(directory, recordings)
```

**After (3.0.1):**
```gleam
// Multiple files: mocks/GET_api.example.com_users_a3f5b2.json, etc.
storage.save_recordings(directory, recordings, matching_config)
```

### API Changes (BREAKING)

Both recording save functions now require a `matching_config` parameter:

**`storage.save_recordings()`**
```gleam
// Before:
storage.save_recordings(directory, recordings)

// After:
storage.save_recordings(directory, recordings, matching_config)
```

**`storage.save_recording_immediately()`**
```gleam
// Before:
storage.save_recording_immediately(directory, recording)

// After:
storage.save_recording_immediately(directory, recording, matching_config)
```

### Added Dependencies

- `gleam_crypto >= 1.5.1 and < 2.0.0` - Used for generating unique filename hashes

## Upgrading

Update your dependencies:

```toml
[dependencies]
dream_http_client = ">= 3.0.1 and < 4.0.0"
```

Then run:

```bash
gleam deps download
```

### Migration Notes

**No migration required for most users** - if you use the `recorder` module (recommended), your code works unchanged.

**If you call `storage` functions directly** (rare):

Add the `matching_config` parameter:

```gleam
let matching_config = matching.match_url_only()
storage.save_recordings(directory, recordings, matching_config)
storage.save_recording_immediately(directory, rec, matching_config)
```

**Directory structure:**

New recordings are saved as individual files. Existing `recordings.json` files still load correctly - the system handles both formats transparently.

## Internal Changes

- Modified `storage.load_recordings()` to scan directory for all `.json` files
- Modified `storage.save_recordings()` to write individual files
- Modified `storage.save_recording_immediately()` to write individual files
- Added `build_filename()` function for generating hybrid filenames
- Added `sanitize_for_filename()` function for safe filename generation
- Added `generate_hash()` function using SHA256 for uniqueness
- Modified `recorder.add_recording()` to pass matching config to storage

## Testing

All 97 tests pass:

```
97 passed, no failures
```

## Documentation

- [dream_http_client](https://hexdocs.pm/dream_http_client) - v3.0.1
- [Full Documentation](https://github.com/TrustBound/dream/tree/main/modules/http_client)

## Community

- 📖 [Full Documentation](https://github.com/TrustBound/dream/tree/main/modules/http_client)
- 💬 [Discussions](https://github.com/TrustBound/dream/discussions)
- 🐛 [Report Issues](https://github.com/TrustBound/dream/issues)
- 🤝 [Contributing Guide](https://github.com/TrustBound/dream/blob/main/CONTRIBUTING.md)

---

**Full Changelog:** [CHANGELOG.md](https://github.com/TrustBound/dream/blob/main/modules/http_client/CHANGELOG.md)
