# Publishing Strategy

**How Dream modules are published to Hex.pm**

Dream uses a **monorepo** approach where all modules live in a single repository but are published independently to Hex.pm. This document explains how the publishing process works.

## Overview

- **Repository Structure**: All modules live in `modules/` directory
- **Independent Publishing**: Each module is published separately with its own version
- **Automated Workflow**: GitHub Actions automatically publishes when version numbers change
- **Manual Override**: Maintainers can trigger manual publishes if needed

## Module List

The following modules are published independently:

- `dream_config` - Configuration management
- `dream_http_client` - HTTP client with streaming
- `dream_postgres` - PostgreSQL utilities
- `dream_opensearch` - OpenSearch client
- `dream_json` - JSON encoding utilities
- `dream_ets` - Type-safe ETS storage

## Publishing Process

### Automatic Publishing

When code is merged to `main`, GitHub Actions automatically:

1. **Checks version changes** - Compares current version to previous commit
2. **Builds and tests** - Ensures the module compiles and tests pass
3. **Publishes to Hex** - If version changed, publishes the new version
4. **Publishes docs** - Updates documentation on HexDocs

**No manual intervention needed** - just bump the version and merge!

### Manual Publishing

If you need to publish manually (e.g., for a hotfix):

```bash
cd modules/<module_name>
gleam publish
gleam docs publish
```

## Version Management

### Semantic Versioning

All modules follow [Semantic Versioning](https://semver.org/):

- **MAJOR** (1.0.0 → 2.0.0) - Breaking changes
- **MINOR** (1.0.0 → 1.1.0) - New features (backward compatible)
- **PATCH** (1.0.0 → 1.0.1) - Bug fixes (backward compatible)

### Updating Versions

1. **Edit `gleam.toml`** in the module directory:
   ```toml
   version = "0.1.1"
   ```

2. **Update CHANGELOG.md** (if the module has one):
   ```markdown
   ## 0.1.1 - 2025-11-20
   - Fixed bug in configuration loading
   ```

3. **Commit and push**:
   ```bash
   git add modules/<module_name>/gleam.toml
   git commit -m "chore(<module_name>): bump version to 0.1.1"
   git push origin main
   ```

4. **GitHub Actions handles the rest** - Automatically publishes when merged

### Version Independence

Each module has its own version number. You can update one module without affecting others:

- `dream_config` can be at `0.1.5`
- `dream_http_client` can be at `0.2.0`
- `dream_postgres` can be at `0.1.0`

This allows independent release cycles based on each module's needs.

## Workflow Details

### Version Detection

The GitHub Actions workflow:

1. Detects all modules in the `modules/` directory
2. For each module, checks if `gleam.toml` version changed compared to previous commit
3. Only publishes if version changed (prevents duplicate publishes)
4. Runs for each module independently in parallel

**Note:** The workflow checks all modules on every push to `main`. This ensures we catch version changes even if the workflow file itself wasn't updated. The version check step quickly skips modules that haven't changed.

### Build and Test

Before publishing, the workflow:

1. Downloads dependencies
2. Builds the module
3. Runs tests
4. Only publishes if all checks pass

### Publishing Steps

For each module with a version change:

1. **Publish to Hex** - `gleam publish`
2. **Build documentation** - `gleam docs build`
3. **Publish documentation** - `gleam docs publish`

## Requirements

### Hex API Key

The workflow requires a `HEX_API_KEY` secret configured in GitHub:

1. Generate API key on [Hex.pm](https://hex.pm)
2. Add as repository secret: `Settings → Secrets → Actions → New repository secret`
3. Name: `HEX_API_KEY`
4. Value: Your Hex API key

### Maintainer Access

Only maintainers with:
- Write access to the repository
- Valid Hex API key
- Permission to publish the package

Can trigger publishes.

## Best Practices

### When to Bump Versions

- **PATCH**: Bug fixes, documentation updates, internal refactoring
- **MINOR**: New features, new functions, backward-compatible changes
- **MAJOR**: Breaking changes, API changes, dependency updates that break compatibility

### Coordinated Releases

If multiple modules need updates for a feature:

1. Update all affected modules in a single PR
2. Bump versions appropriately for each
3. Merge once - all modules publish together

### Changelog

Consider adding a `CHANGELOG.md` to each module:

```markdown
# Changelog

## 0.1.1 - 2025-11-20
- Fixed bug in configuration loading

## 0.1.0 - 2025-11-01
- Initial release
```

## Troubleshooting

### Version Not Publishing

**Check:**
- Is the version actually different from the previous commit?
- Did the build/tests pass?
- Is `HEX_API_KEY` configured correctly?
- Check GitHub Actions logs for errors

### Duplicate Version Error

If Hex rejects a publish because the version already exists:
- Bump to the next version
- Check if someone else already published this version

### Module Not Found

If a module isn't being published:
- Check that `gleam.toml` exists in `modules/<module_name>/`
- Verify the module name matches the directory name
- Check GitHub Actions workflow logs

## Related Documentation

- [Contributing Guide](index.md) - General contribution guidelines
- [Design Principles](../reference/design-principles.md) - Code quality standards
- [Architecture](../reference/architecture.md) - How modules fit together

