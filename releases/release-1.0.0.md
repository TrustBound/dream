# Dream 1.0.0 Release Notes

**Release Date:** November 21, 2025

Dream 1.0.0 marks the initial release to Hex.pm. This release includes the core Dream framework and six independent modules published as separate packages. **Note:** The 1.0.0 version number is required by Hex.pm for publication (versions below 1.0.0 require explicit confirmation that semantic versioning is not being used). The API is functional and production-ready, but may still evolve with breaking changes as we gather feedback from the community.

## What's New

### Initial Hex.pm Publication

Dream and all modules are now available on Hex.pm:

- **dream** - Core web framework
- **dream_config** - Type-safe configuration management
- **dream_http_client** - HTTP client with streaming support
- **dream_postgres** - PostgreSQL utilities
- **dream_opensearch** - OpenSearch client
- **dream_json** - JSON encoding utilities
- **dream_ets** - Type-safe ETS storage

### Installation

Install the core framework:
```bash
gleam add dream
```

Or install individual modules:
```bash
gleam add dream_config
gleam add dream_http_client
gleam add dream_postgres
gleam add dream_opensearch
gleam add dream_json
gleam add dream_ets
```

### CI/CD Publishing

- Fixed authentication issues in GitHub Actions workflows
- Added `FORCE_PUBLISH` bypass for hotfix scenarios
- Automated publishing when version numbers change
- Documentation publishing integrated into CI pipeline

## Breaking Changes

### Version Numbering

All packages start at 1.0.0 (not 0.1.0) to comply with Hex.pm's publishing requirements. **Important:** This version number does NOT indicate API stability - it's a technical requirement for Hex.pm publication. The API is usable and tested, but expect breaking changes in future releases as the framework matures based on community feedback. This is the first published version of all packages.

### Module Structure

Modules are now published as separate packages. If you were using local path dependencies, update to Hex dependencies:

**Before:**
```toml
[dependencies]
dream_config = { path = "../modules/config" }
```

**After:**
```toml
[dependencies]
dream_config = ">= 1.0.0 and < 2.0.0"
```

## What's Included

### Core Framework (dream)

- Mist HTTP server adapter
- Builder pattern for server, router, and HTTP client
- Path parameter extraction
- Wildcard routing patterns
- Middleware support
- Custom context system
- Unified error handling
- Parameter validation functions

### Modules

**dream_config** - Configuration management
- Environment variable loading
- `.env` file support
- Type-safe configuration access

**dream_http_client** - HTTP client
- Non-streaming and streaming requests
- Builder pattern for request configuration
- All HTTP methods supported

**dream_postgres** - PostgreSQL utilities
- Type-safe query helpers
- Connection pooling via Pog
- Simplified error handling

**dream_opensearch** - OpenSearch client
- Document indexing and search
- Query builder helpers
- Bulk operations

**dream_json** - JSON encoding utilities
- Optional value encoding
- Timestamp encoding
- Type-safe JSON helpers

**dream_ets** - ETS storage
- Type-safe table interface
- CRUD operations
- Counter helpers
- Table persistence

## Documentation

All packages include comprehensive documentation on HexDocs:
- [dream](https://hexdocs.pm/dream)
- [dream_config](https://hexdocs.pm/dream_config)
- [dream_http_client](https://hexdocs.pm/dream_http_client)
- [dream_postgres](https://hexdocs.pm/dream_postgres)
- [dream_opensearch](https://hexdocs.pm/dream_opensearch)
- [dream_json](https://hexdocs.pm/dream_json)
- [dream_ets](https://hexdocs.pm/dream_ets)

## Migration Guide

If you were using Dream from a local Git dependency or path:

1. **Update your `gleam.toml`:**
   ```toml
   [dependencies]
   dream = ">= 1.0.0 and < 2.0.0"
   ```

2. **Update module dependencies:**
   ```toml
   [dependencies]
   dream_config = ">= 1.0.0 and < 2.0.0"
   dream_postgres = ">= 1.0.0 and < 2.0.0"
   # etc.
   ```

3. **Run `gleam deps download`** to fetch from Hex

4. **No code changes required** - the API is identical

## Versioning and API Stability

**Current Status:** The API is functional and being used in production, but is NOT yet considered stable. Breaking changes may occur in future versions as we incorporate community feedback.

**Semantic Versioning:** We follow [Semantic Versioning](https://semver.org/) conventions:
- **MAJOR** (1.0.0 → 2.0.0) - Breaking changes (expect these as the API evolves)
- **MINOR** (1.0.0 → 1.1.0) - New features (backward compatible)
- **PATCH** (1.0.0 → 1.0.1) - Bug fixes (backward compatible)

**Why 1.0.0?** Hex.pm requires version 1.0.0 or higher for publication without manual confirmation. Starting at 1.0.0 allows automated CI/CD publishing, but does not imply the API won't have breaking changes. Pin your dependencies carefully and test before upgrading.

## Next Steps

- Read the [5-Minute Quickstart](https://github.com/TrustBound/dream/blob/main/docs/quickstart.md) to get started
- Explore the [Learning Path](https://github.com/TrustBound/dream/tree/main/docs/learn) for structured tutorials
- Check out [Working Examples](https://github.com/TrustBound/dream/tree/main/examples) for complete applications
- Review [Architecture Reference](https://github.com/TrustBound/dream/blob/main/docs/reference/architecture.md) for deep dives

## Thank You

Thank you to everyone who has provided feedback, reported issues, and contributed to Dream. This initial Hex publication represents a significant milestone - making Dream easily accessible to the Gleam community.

---

**Full Changelog:** [CHANGELOG.md](https://github.com/TrustBound/dream/blob/main/CHANGELOG.md)

