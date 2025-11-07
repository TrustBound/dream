# Changelog

All notable changes to Dream will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/FileStory/dream/compare/v0.0.1...HEAD
[0.0.1]: https://github.com/FileStory/dream/releases/tag/v0.0.1

