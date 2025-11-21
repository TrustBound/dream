# Changelog

All notable changes to Dream will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/TrustBound/dream/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/TrustBound/dream/compare/v0.0.1...v0.1.0
[0.0.1]: https://github.com/TrustBound/dream/releases/tag/v0.0.1

