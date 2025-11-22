# Changelog

All notable changes to Dream will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/TrustBound/dream/compare/v1.0.2...HEAD
[1.0.2]: https://github.com/TrustBound/dream/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/TrustBound/dream/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/TrustBound/dream/compare/v0.1.0...v1.0.0
[0.1.0]: https://github.com/TrustBound/dream/compare/v0.0.1...v0.1.0
[0.0.1]: https://github.com/TrustBound/dream/releases/tag/v0.0.1

