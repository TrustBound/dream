# Dream 2.3.3 Release Notes

**Release Date:** March 7, 2026

This release fixes a bug where multiple `Set-Cookie` headers were collapsed into a single header, causing browsers to only receive the last cookie.

## Key Highlights

- **Set-Cookie fix**: Multiple cookies now each produce their own `Set-Cookie` header per RFC 6265
- **Comprehensive test coverage**: 7 new tests validate multi-cookie behavior and RFC compliance

## Fixed

The mist response converter used `set_header` (which replaces existing headers with the same name) for every header, including `Set-Cookie`. RFC 6265 requires each cookie to be sent as a separate `Set-Cookie` header — browsers do not parse comma-separated `Set-Cookie` values.

`add_header` now uses `prepend_header` (which allows duplicates) for `set-cookie` headers, and `set_header` (which replaces) for everything else. This matches the Gleam standard library's own `set_cookie` convention.

### Before

```gleam
fn add_header(acc, header) {
  http_response.set_header(acc, header.0, header.1)
}
```

### After

```gleam
fn add_header(acc, header) {
  case header.0 {
    "set-cookie" -> http_response.prepend_header(acc, header.0, header.1)
    _ -> http_response.set_header(acc, header.0, header.1)
  }
}
```

## Added

- `count_mist_headers` test matcher for verifying header counts by name
- `extract_all_mist_header_values` test matcher for extracting all values of a header
- 7 new tests covering:
  - Multiple cookies produce separate `Set-Cookie` headers
  - Each cookie value is individually present
  - Three cookies produce three headers
  - Manual `Set-Cookie` in headers coexists with cookies from the `cookies` field
  - Duplicate non-cookie headers are still deduplicated
  - Cookies with attributes each get their own header
  - Cookies alongside other headers don't interfere

## Upgrading

Update your dependencies:

```toml
[dependencies]
dream = ">= 2.3.3 and < 3.0.0"
```

Then run:

```bash
gleam deps download
```

## Documentation

- [dream](https://hexdocs.pm/dream) - v2.3.3

---
