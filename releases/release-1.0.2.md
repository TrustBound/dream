# Dream 1.0.2 Release Notes

**Release Date:** November 21, 2025

Dream 1.0.2 is a documentation-focused release that significantly improves the README and adds new concept documentation to make Dream more accessible to newcomers.

## What's Changed

### README Refactor

The README has been completely rewritten to be more accessible and scannable:

- **Reduced from 520 lines to ~130 lines** - Much easier to scan and understand
- **Zero-knowledge friendly** - Explains what Dream, Gleam, and BEAM are for complete beginners
- **Complete working example** - Shows a full server with line-by-line explanations
- **Better structure** - Quick introduction with links to detailed docs

**Before:** Assumed readers knew what Dream, Gleam, and BEAM were, showed type signatures instead of working examples, and was too dense to scan quickly.

**After:** Starts from zero knowledge, shows working code with explanations, and points to detailed docs for deeper dives.

### New Documentation

Added standalone documentation files for better organization:

- **[How It Works](https://github.com/TrustBound/dream/blob/main/docs/concepts/how-it-works.md)** - Detailed explanation of request flow from arrival to response
- **[Project Structure](https://github.com/TrustBound/dream/blob/main/docs/concepts/project-structure.md)** - How to organize a real Dream application
- **[Core Patterns](https://github.com/TrustBound/dream/blob/main/docs/concepts/patterns.md)** - Operations and multi-format response patterns
- **[Why the BEAM?](https://github.com/TrustBound/dream/blob/main/docs/reference/why-beam.md)** - Deep dive into the BEAM runtime and its benefits

All detailed technical content that was in the README has been moved to these dedicated files, making the README a quick introduction that points to the right docs.

### Module Documentation Updates

All module README files now include HexDocs documentation badges for quick access to API documentation:
- `dream_config`
- `dream_ets`
- `dream_http_client`
- `dream_json`
- `dream_opensearch`
- `dream_postgres`

### Terminology Fixes

Clarified the distinction between:
- **Controller** - A module/file containing multiple actions (e.g., `controllers/users_controller.gleam`)
- **Controller Action** - A function within that controller that handles a request (e.g., `index`, `show`)

This distinction is now consistently used throughout the documentation.

## Upgrading

Update your dependencies to 1.0.2:

```toml
[dependencies]
dream = ">= 1.0.2 and < 2.0.0"
dream_config = ">= 1.0.2 and < 2.0.0"
dream_ets = ">= 1.0.2 and < 2.0.0"
dream_http_client = ">= 1.0.2 and < 2.0.0"
dream_json = ">= 1.0.2 and < 2.0.0"
dream_opensearch = ">= 1.0.2 and < 2.0.0"
dream_postgres = ">= 1.0.2 and < 2.0.0"
```

Then run:
```bash
gleam deps download
```

**Note:** This is a documentation-only release. No code changes were made. Upgrading is optional but recommended for access to improved documentation.

## No Breaking Changes

This release contains no breaking changes or code modifications. All functionality remains identical to 1.0.1.

## Documentation

All packages are available with updated documentation on HexDocs:
- [dream](https://hexdocs.pm/dream)
- [dream_config](https://hexdocs.pm/dream_config)
- [dream_http_client](https://hexdocs.pm/dream_http_client)
- [dream_postgres](https://hexdocs.pm/dream_postgres)
- [dream_opensearch](https://hexdocs.pm/dream_opensearch)
- [dream_json](https://hexdocs.pm/dream_json)
- [dream_ets](https://hexdocs.pm/dream_ets)

---

**Full Changelog:** [CHANGELOG.md](https://github.com/TrustBound/dream/blob/main/CHANGELOG.md)

