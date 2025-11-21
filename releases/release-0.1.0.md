# Dream 0.1.0 Release Notes

**Release Date:** November 19, 2025

Dream 0.1.0 represents a significant milestone in API consistency and documentation completeness. This release introduces unified error handling, improved parameter validation, and comprehensive documentation of Dream's architecture and patterns.

## What's New

### Unified Error Handling

Dream now uses a single `dream.Error` type throughout the framework and applications. This eliminates the need for error mapping between layers and keeps controllers thin and readable.

**Before:**
```gleam
// Multiple error types, complex mapping
case get_user(db, id) {
  Ok(user) -> Ok(user)
  Error(NotFound) -> Error(HttpError.NotFound("User not found"))
  Error(DbError) -> Error(HttpError.InternalServerError("Database error"))
}
```

**After:**
```gleam
// Single error type, no mapping needed
case get_user(db, id) {
  Ok(user) -> Ok(user)
  Error(err) -> Error(err)  // Already dream.Error
}
```

### Improved Parameter Validation

New `require_*` functions provide semantic clarity and safe parameter extraction:

- `require_int(request, "id")` - Extract and validate integer path parameters
- `require_string(request, "name")` - Extract string path parameters
- `require_form(request)` - Extract form data
- `require_field(form, "email")` - Extract form field
- `require_field_int(form, "age")` - Extract and validate integer form field
- `field_optional(form, "description")` - Extract optional form field

All functions return `Result(T, dream.Error)`, enabling flat `use` chains without nested `case` statements.

### Consolidated Imports

Import all HTTP utilities from a single module:

```gleam
import dream/http.{type Request, type Response, require_int, json_response, ok}
```

No more importing from multiple submodules. Error constructors and method constants still come from their specific modules when needed.

### Comprehensive Documentation

**New Documentation:**
- MVC architecture guide with complete examples
- Modules ecosystem documentation
- Operations pattern guide
- API stability and versioning policy
- Enhanced controllers-and-models guide

**Updated Documentation:**
- All examples use current patterns (require_*, flat use chains, unified errors)
- Cross-references verified and corrected
- Import patterns standardized

## Breaking Changes

### Parameter Validation Functions Renamed

The following functions have been renamed for semantic clarity:

- `get_int` → `require_int`
- `get_string` → `require_string`
- `get_form` → `require_form`
- `field` → `require_field`
- `field_int` → `require_field_int`
- `field_optional` → unchanged (not a "required" field)

**Migration:**
```gleam
// Old
use id <- result.try(http.get_int(request, "id"))

// New
use id <- result.try(http.require_int(request, "id"))
```

### Error Handling Unified

If you were using custom error types in models or operations, you'll need to update them to use `dream.Error`:

```gleam
// Old
pub fn get_user(db: Connection, id: Int) -> Result(User, DataError) {
  // ...
}

// New
import dream/http/error.{type Error, NotFound, InternalServerError}

pub fn get_user(db: Connection, id: Int) -> Result(User, Error) {
  case sql.get_user(db, id) {
    Ok(row) -> Ok(row_to_user(row))
    Error(query.NotFound) -> Error(NotFound("User not found"))
    Error(_) -> Error(InternalServerError("Database error"))
  }
}
```

## What's Unlikely to Change

While nothing is guaranteed until 1.0.0, these core components are unlikely to change:

- Context system (per-request context pattern)
- Services pattern (application-level dependencies)
- Request/Response types (core HTTP structures)
- Router (route matching and middleware patterns)

See [API Stability](docs/reference/architecture.md#api-stability) for details.

## Examples Updated

All example applications have been updated to use the new patterns:
- `examples/tasks` - Full-featured task app with HTMX
- `examples/database` - CRUD operations with PostgreSQL
- `examples/multi_format` - Content negotiation patterns
- `examples/simple` - Minimal HTTP client usage
- `examples/custom_context` - Custom context patterns
- `examples/rate_limiter` - Middleware patterns
- `examples/streaming` - Streaming responses
- `examples/static` - Static file serving

## Next Steps

- Read the [5-Minute Quickstart](docs/quickstart.md) to get started
- Explore the [Learning Path](docs/learn/) for structured tutorials
- Check out [Working Examples](examples/) for complete applications
- Review [Architecture Reference](docs/reference/architecture.md) for deep dives

## Thank You

Thank you to everyone who has provided feedback, reported issues, and contributed to Dream. Your input has been invaluable in shaping this release.

---

**Full Changelog:** [CHANGELOG.md](../CHANGELOG.md)

