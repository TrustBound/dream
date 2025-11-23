# Changelog

All notable changes to Dream will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.0.0] - 2025-11-23

### 🚨 Breaking Changes

**Router API Change**
- Changed `router` from a constant to a function: `router()`
  - **Migration:** Change all `router` references to `router()` in your code
  - **Reason:** Radix trie implementation requires runtime initialization with `dict.new()`
  - **Impact:** All routers in examples and applications must be updated

**Default Context and Services**
- `server.new()` now defaults to `EmptyContext` and `EmptyServices` instead of requiring `AppContext`
  - **Migration:** Remove unnecessary `context()` and `services()` calls if you don't need custom context/services
  - **Impact:** Simplified API for applications that don't require per-request context
  - **Note:** Applications using custom context/services are unaffected

### Added

**Radix Trie Router**
- Complete router rewrite using radix trie data structure for O(path depth) performance
  - Replaces linear search O(N routes) with O(path depth) lookup
  - Benchmarks show 241x faster for first route match, 1353x faster for route-not-found cases
  - Consistent ~1.3-1.5μs lookup time regardless of route count (100 or 1000 routes)
- New modules:
  - `dream/router/trie` - Radix trie implementation with comprehensive inline documentation
  - `dream/router/parser` - Path pattern parser for converting string paths to segments
- Parameter name remapping support for routes sharing parameter positions
  - Routes like `/users/:id` and `/users/:user_id/posts` now work correctly
  - Original parameter names preserved per-route, remapped after lookup
- Extension stripping for content negotiation
  - Routes without explicit extensions (e.g., `/products`) now match paths with extensions (e.g., `/products.json`)
  - Controllers can use `param.format` for content type detection
  - Explicit extension patterns (e.g., `*.{jpg,png}`) take precedence
- Comprehensive test suite:
  - 62+ router unit tests covering all pattern types and edge cases
  - Performance benchmark tests comparing radix trie vs linear router
  - Extension stripping tests for literal routes, parameter routes, priority, and edge cases
  - Parameter remapping tests with multiple params and wildcards

**Context Improvements**
- Added `EmptyContext` type for applications that don't require per-request context
- `server.new()` now defaults to `EmptyContext` and `EmptyServices`
  - No need to call `.context()` or `.services()` for simple applications
  - Custom context/services still supported via `.context()` and `.services()` builder methods
- Updated all example applications to use simplified API where appropriate

**Documentation Updates**
- Added radix trie performance information to quickstart and concepts documentation
- Added type-safety trade-off explanation with link to Discussion #15
- Updated all documentation from `router` constant to `router()` function
- Added comprehensive comments to README example explaining middleware and controller patterns
- Updated all examples to use full parameter names (`request`, `context`, `services`) instead of abbreviations
- Fixed inline documentation examples to use correct builder patterns and unqualified imports
- Updated all context/services documentation to reflect new defaults

### Changed

**Router Implementation**
- `Router` type now holds `trie.RadixTrie` instead of `List(Route)`
- Route insertion now happens via radix trie instead of list append
- Route lookup uses trie traversal with parameter extraction and remapping
- Removed deprecated builder pattern functions (`method()`, `path()`, `controller()`, `middleware()`)
- Removed deprecated `match_path()` function
- Anonymous functions extracted to named helpers throughout router module

**Code Quality**
- Eliminated all nested `case` statements across codebase
  - `dream/http/transaction`: Refactored `get_header` and `get_cookie` to use recursive helpers
  - `dream/servers/mist/handler`: Extracted anonymous function to `create_request_handler`
  - `dream/router`: Extracted anonymous function to `apply_middleware_to_controller`
- Removed all anonymous functions by extracting to named helpers
- Fixed all compiler warnings (unused imports, redundant tuples, unused arguments)

**Example Applications**
- Updated all 8 example applications to use `router()` function
- Simplified example code by removing unnecessary `context()` and `services()` calls
- Updated controller and middleware signatures to use full parameter names
- Fixed PostgreSQL port standardization (all examples use port 5435)
- Improved Makefiles with Docker availability checks and better error handling

**Internal Architecture**
- Added `dream.execute_route()` function to centralize route execution logic
- Handler now passes extracted parameters directly to `execute_route()` (avoids redundant lookups)
- Removed redundant `set_params()` calls in handler

### Fixed
- Multi-wildcard routes now correctly match zero segments (e.g., `/public/` matches `/public/**filepath`)
- Extension stripping preserves original parameter values for format detection
  - `/products/:id` matching `/products/1.json` now correctly extracts `id=1.json` with `format=json`
- Parameter name consistency when routes share parameter positions
- Database example integration tests (parameter flow fixed)
- Multi-format example PostgreSQL connection (port mismatch resolved)
- All compiler warnings resolved (unused imports, redundant code, unused arguments)

### Performance
- Router lookup improved from O(N routes) to O(path depth)
- Benchmarks (100 routes):
  - First route: 0.56μs (was 135μs) - 241x faster
  - Middle route: 1.44μs (was 70μs) - 49x faster  
  - Last route: 1.35μs (was 7.3μs) - 5.4x faster
  - Not found: 1.85μs (was 2500μs) - 1353x faster

### Migration Guide

**1. Update router references:**
```gleam
// Before (v1.x)
import dream/router.{router}
let app_router = router |> route(...)

// After (v2.0)
import dream/router.{router}
let app_router = router() |> route(...)
```

**2. Simplify server setup (optional):**
```gleam
// Before (v1.x)
server.new()
|> context(AppContext(request_id: "..."))
|> services(EmptyServices)
|> router(app_router)

// After (v2.0) - if you don't need custom context/services
server.new()
|> router(app_router)
```

**3. Update imports if using `AppContext`:**
```gleam
// Before (v1.x) - AppContext was the default
import dream/context.{AppContext}

// After (v2.0) - EmptyContext is the default, import AppContext if needed
import dream/context.{type AppContext, new_context}

server.new()
|> context(new_context("req-123"))  // Explicit context needed
```

### Acknowledgments

Special thanks to [Louis Pilfold](https://github.com/lpil) for suggesting the radix trie approach that made this performance breakthrough possible.

## [1.0.2] - 2025-11-21

### Changed
- Completely refactored README for better accessibility and clarity
  - Reduced from 520 lines to ~130 lines for better scannability
  - Added zero-knowledge friendly introduction explaining what Dream, Gleam, and BEAM are
  - Included complete working example with line-by-line explanations
  - Moved detailed technical content to standalone documentation files
- Added new documentation files:
  - `docs/concepts/how-it-works.md` - Request flow explanation
  - `docs/concepts/project-structure.md` - Project organization guide
  - `docs/concepts/patterns.md` - Operations and multi-format patterns
  - `docs/reference/why-beam.md` - BEAM runtime explanation
- Updated documentation index to include new concept documentation
- Fixed terminology: clarified distinction between "controller" (module) and "controller action" (function)
- Added HexDocs documentation badges to all module README files (dream_config, dream_ets, dream_http_client, dream_json, dream_opensearch, dream_postgres)

## [1.0.1] - 2025-11-22

### Fixed
- Fixed logo display on hex.pm by using full GitHub URLs instead of relative paths in README files
- Added Dream logo to all module README files (dream_config, dream_ets, dream_http_client, dream_json, dream_opensearch, dream_postgres)

## [1.0.0] - 2025-11-21

### Added
- Initial stable release to Hex.pm
- All modules published as separate packages (dream_config, dream_http_client, dream_postgres, dream_opensearch, dream_json, dream_ets)

## [0.1.0] - 2025-11-19

### Added
- Unified error handling with `dream.Error` type across framework and applications
- Parameter validation functions: `require_int`, `require_string`, `require_form`, `require_field`, `require_field_int`
- Consolidated HTTP imports via `dream/http` module re-exporting all HTTP utilities
- Comprehensive MVC architecture documentation
- Modules ecosystem documentation (dream_postgres, dream_http_client, dream_opensearch, dream_config, dream_json, dream_ets)
- Operations pattern guide for complex business logic
- API stability documentation
- Enhanced controllers-and-models guide with more examples
- Multi-format response patterns documentation

### Changed
- Parameter validation functions renamed from `get_*` to `require_*` for semantic clarity
- All documentation updated to use consolidated `dream/http` imports
- Error handling unified across framework - models, controllers, and operations all use `dream.Error`
- Documentation examples updated to use flat `use` chains instead of nested `case` statements
- Response helpers pattern documented and standardized across examples

### Fixed
- Nested case statements removed from parameter validation functions
- Documentation cross-references verified and corrected
- Import patterns standardized across all documentation

## [0.0.1] - 2025-11-06

### Added
- Initial release
- Mist HTTP server adapter
- Builder pattern for server, router, and HTTP client
- Path parameter extraction with PathParam type
- Wildcard routing patterns (single `*` and multi `**` segment matching)
- Middleware support with chaining
- Custom context system
- PostgreSQL support via Pog
- JSON validation utilities
- HTTP client with streaming and non-streaming modes
- Static file serving controller
- Complete documentation restructure
- Getting Started guide
- Tutorials for routing, database, authentication, HTTP client, and multi-format responses
- Guides for controllers/models, middleware, testing, deployment, and database
- Reference documentation for architecture and design principles
- Examples overview documentation
- Example applications (simple, database, custom_context, singleton, static, multi_format, streaming)

### Changed
- Documentation moved from `documentation/` to `docs/`
- Examples restructured as standalone Gleam projects with integration tests
- All code examples now include proper imports
- Improved documentation tone and consistency

[Unreleased]: https://github.com/TrustBound/dream/compare/v2.0.0...HEAD
[2.0.0]: https://github.com/TrustBound/dream/compare/v1.0.2...v2.0.0
[1.0.2]: https://github.com/TrustBound/dream/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/TrustBound/dream/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/TrustBound/dream/compare/v0.1.0...v1.0.0
[0.1.0]: https://github.com/TrustBound/dream/compare/v0.0.1...v0.1.0
[0.0.1]: https://github.com/TrustBound/dream/releases/tag/v0.0.1

