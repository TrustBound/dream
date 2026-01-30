# dream_http_client 4.1.0 Release Notes

**Release Date:** January 28, 2026

dream_http_client 4.1.0 makes recording fixtures safer by writing them atomically, so readers never observe partial files during capture.

## Key Highlights

- **Atomic fixture writes**: recordings are written to a temp file and renamed into place.
- **Safer concurrent reads**: readers only see complete JSON files.
- **Test coverage**: storage tests verify atomic behavior and cleanup.

## Changes

### Atomic Recording Writes

Recording fixtures are now written atomically:

- Write content to a temporary file
- Rename into place once complete

This prevents consumers from reading partially-written recordings during capture.

## Upgrading

Update your dependency:

```toml
[dependencies]
dream_http_client = ">= 4.1.0 and < 5.0.0"
```
