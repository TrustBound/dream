# Dream 2.0.0 Release Notes

**Release Date:** November 23, 2025

Dream 2.0.0 is a major release that rewrites the router using a radix trie data structure, delivering dramatic performance improvements while maintaining Dream's ergonomic API. This release also simplifies the developer experience by introducing `EmptyContext` and `EmptyServices` as defaults.

## 🚨 Breaking Changes

### Router API Change

The `router` constant has been changed to a function `router()` to support the new radix trie implementation.

**Migration:**
```gleam
// Before (v1.x)
import dream/router.{router}
let app_router = router |> route(...)

// After (v2.0)
import dream/router.{router}
let app_router = router() |> route(...)
```

**Why:** The radix trie requires runtime initialization with `dict.new()`, which cannot be used in Gleam constants. This breaking change was necessary to achieve O(path depth) performance.

### Default Context and Services

`server.new()` now defaults to `EmptyContext` and `EmptyServices` instead of requiring `AppContext`.

**Migration (if you don't use custom context/services):**
```gleam
// Before (v1.x)
import dream/context.{AppContext}

server.new()
|> context(AppContext(request_id: "..."))
|> services(EmptyServices)
|> router(app_router)

// After (v2.0) - Much simpler!
server.new()
|> router(app_router)
|> listen(3000)
```

**Migration (if you DO use custom context/services):**
```gleam
// Before (v1.x)
import dream/context.{AppContext}

server.new()
|> context(AppContext(request_id: "..."))
|> router(app_router)

// After (v2.0) - Explicit context() call still works
import dream/context.{type AppContext, new_context}

server.new()
|> context(new_context("req-123"))
|> router(app_router)
```

**Why:** Most applications don't need per-request context. This change reduces boilerplate and makes simple applications even simpler.

## Performance Improvements

### Radix Trie Router

The router has been completely rewritten using a radix trie data structure, replacing the previous linear search with O(path depth) lookup.

**Benchmark Results (100 routes):**

| Scenario | Before (Linear) | After (Radix Trie) | Improvement |
|----------|----------------|-------------------|-------------|
| First route match | 135.0μs | 0.56μs | **241x faster** |
| Middle route match | 70.0μs | 1.44μs | **49x faster** |
| Last route match | 7.3μs | 1.35μs | **5.4x faster** |
| Route not found | 2500.0μs | 1.85μs | **1353x faster** |

**Scalability:**

The radix trie delivers consistent ~1.3-1.5μs lookup times regardless of route count. Whether you have 100 routes or 1000 routes, performance remains constant. The router is now fast enough that it will never be your bottleneck.

## New Features

### EmptyContext Type

Added `EmptyContext` for applications that don't require per-request context:

```gleam
import dream/context.{type EmptyContext}
import dream/servers/mist/server

pub fn main() {
  server.new()  // Defaults to EmptyContext and EmptyServices
  |> router(my_router())
  |> listen(3000)
}
```

### Extension Stripping for Content Negotiation

Routes without explicit extensions now match paths with extensions, enabling controllers to handle format detection:

```gleam
// Route definition
router()
|> route(method: Get, path: "/products/:id", controller: show_product, middleware: [])

// Matches both:
// - /products/1 → id = "1", format = None
// - /products/1.json → id = "1.json", format = Some("json")

fn show_product(request: Request, context: Context, services: Services) -> Response {
  use id_param <- result.try(require_string(request, "id"))
  
  case id_param.format {
    Some("json") -> json_response(ok, product_data)
    Some("csv") -> csv_response(ok, product_data)
    _ -> html_response(ok, product_view)
  }
}
```

Explicit extension patterns (e.g., `*.{jpg,png}`) take precedence over extension stripping.

### Parameter Name Remapping

Routes can now use different parameter names at the same position without conflict:

```gleam
router()
|> route(method: Get, path: "/users/:id", controller: show_user, middleware: [])
|> route(method: Get, path: "/users/:user_id/posts", controller: user_posts, middleware: [])

// Both routes work correctly:
// - /users/123 → extracts "id=123"
// - /users/456/posts → extracts "user_id=456"
```

The router preserves each route's original parameter names and remaps them after lookup.

## Code Quality Improvements

### Eliminated Nested Cases

All nested `case` statements have been removed across the codebase:

- `dream/http/transaction`: Refactored `get_header` and `get_cookie` to use recursive helpers
- `dream/router/trie`: Refactored `lookup_in_node` to extract nested logic
- Test helper functions refactored to use flat case structures

### Removed Anonymous Functions

All anonymous functions have been extracted to named helpers:

- `dream/servers/mist/handler`: `create_request_handler`
- `dream/router`: `apply_middleware_to_controller`
- `dream/http/transaction`: `header_name_mismatch`, `cookie_name_mismatch`

### Fixed All Compiler Warnings

- Removed unused imports across all modules
- Fixed redundant tuples
- Removed unused function arguments
- Added proper underscores for intentionally unused parameters

## New Modules

### dream/router/trie

Complete radix trie implementation with comprehensive inline documentation:

- `new()` - Create a new empty trie
- `insert()` - Insert a route into the trie
- `lookup()` - Look up a path and extract parameters
- Supports all Dream routing features: literals, parameters, wildcards, multi-wildcards, extension patterns

### dream/router/parser

Path pattern parser for converting string paths to structured segments:

- `parse_path()` - Parse a path string into segments
- `Segment` type: `Literal`, `Param`, `SingleWildcard`, `MultiWildcard`, `ExtensionPattern`

## Documentation Updates

### Performance Information

All router documentation now explains radix trie performance:

- O(path depth) lookup complexity
- Consistent ~1.3-1.5μs performance regardless of route count
- Benchmarks showing 100-1000x improvements for common scenarios

### Type Safety Trade-off

Documentation now clearly explains Dream's design decision:

- ✅ Controllers ARE type-checked (context, services types verified by compiler)
- ❌ Path parameters are validated at runtime, not compile-time
- This favors ergonomic APIs over compile-time guarantees
- Links to [Discussion #15](https://github.com/TrustBound/dream/discussions/15) for type-safe routing exploration

### Updated Examples

- All 8 example applications updated to use `router()` function
- Examples simplified by removing unnecessary `context()` and `services()` calls
- Controllers and middleware use full parameter names (`request`, `context`, `services`)
- README example includes comprehensive comments explaining middleware and controller patterns

## Bug Fixes

- Multi-wildcard routes now correctly match zero segments (e.g., `/public/` matches `/public/**filepath`)
- Extension stripping preserves original parameter values for format detection
- Parameter name consistency when routes share parameter positions
- Database example integration tests (parameter flow fixed)
- Multi-format example PostgreSQL connection (port mismatch resolved)

## Internal Architecture Changes

### Centralized Route Execution

Added `dream.execute_route()` to centralize route execution logic:

- Handler now passes extracted parameters directly to `execute_route()`
- Avoids redundant `find_route()` calls
- Improved performance and code clarity

### Removed Deprecated Functions

The following deprecated functions have been removed:

- `router.method()` - Use labeled arguments in `route()` instead
- `router.path()` - Use labeled arguments in `route()` instead
- `router.controller()` - Use labeled arguments in `route()` instead
- `router.middleware()` - Use labeled arguments in `route()` instead
- `router.match_path()` - Use `find_route()` instead

## Upgrading

Update your dependencies to 2.0.0:

```toml
[dependencies]
dream = ">= 2.0.0 and < 3.0.0"
```

Then run:
```bash
gleam deps download
```

### Migration Checklist

1. ✅ Change all `router` references to `router()` in your code
2. ✅ Remove unnecessary `context()` and `services()` calls (if not using custom context/services)
3. ✅ If using `AppContext`, import it explicitly: `import dream/context.{type AppContext, new_context}`
4. ✅ Run `gleam test` to verify all tests pass
5. ✅ Run your integration tests to ensure routing still works correctly

## Testing

This release includes comprehensive test coverage:

- **62+ router unit tests** covering all pattern types, parameter remapping, extension stripping, and edge cases
- **Performance benchmark tests** comparing radix trie vs linear router
- **Integration tests** for all 8 example applications
- All tests pass on CI with PostgreSQL integration

## Documentation

All packages are available with updated documentation on HexDocs:
- [dream](https://hexdocs.pm/dream)
- [dream_config](https://hexdocs.pm/dream_config)
- [dream_http_client](https://hexdocs.pm/dream_http_client)
- [dream_postgres](https://hexdocs.pm/dream_postgres)
- [dream_opensearch](https://hexdocs.pm/dream_opensearch)
- [dream_json](https://hexdocs.pm/dream_json)
- [dream_ets](https://hexdocs.pm/dream_ets)

## Community

- 💬 [Discussion #15: Type-safe routing exploration](https://github.com/TrustBound/dream/discussions/15)
- 📖 [Full Documentation](https://github.com/TrustBound/dream/tree/main/docs)
- 🐛 [Report Issues](https://github.com/TrustBound/dream/issues)

## Acknowledgments

Special thanks to [Louis Pilfold](https://github.com/lpil) for suggesting the radix trie approach that made this performance breakthrough possible. His insight that "a trie would be a good fit here" sparked this entire rewrite and delivered the 100-1000x performance improvements we see in this release.

---

**Full Changelog:** [CHANGELOG.md](https://github.com/TrustBound/dream/blob/main/CHANGELOG.md)

**Migration Guide:** See the "Breaking Changes" section above for detailed migration instructions.

