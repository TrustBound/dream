# Publishing Strategy

**How Dream is published to Hex.pm**

This document explains how the `dream` package gets to Hex.pm.

## Overview

- **One package**: This repository publishes the `dream` package only
- **Automated workflow**: GitHub Actions publishes when the version in `gleam.toml` changes on `main`
- **Manual override**: Maintainers can start the workflow by hand

## Modules

Each Dream module has its own repository, its own version and its own release workflow: [dream_config](https://github.com/TrustBound/dream_config), [dream_ets](https://github.com/TrustBound/dream_ets), [dream_http_client](https://github.com/TrustBound/dream_http_client), [dream_json](https://github.com/TrustBound/dream_json), [dream_mock_server](https://github.com/TrustBound/dream_mock_server), [dream_opensearch](https://github.com/TrustBound/dream_opensearch) and [dream_postgres](https://github.com/TrustBound/dream_postgres). Read the contributing guide of a module to release it.

## Publishing Process

### Automatic Publishing

When a change to `gleam.toml` is merged to `main`, the "Publish Dream to Hex" workflow (`.github/workflows/publish-modules.yml`):

1. **Checks the version** - Asks Hex if the version in `gleam.toml` is published already, and stops if it is
2. **Builds and tests** - Runs `gleam build`, `make test-unit` and `make check-snippets`
3. **Publishes to Hex** - Runs `gleam publish --yes`
4. **Tags the release** - Creates and pushes the git tag `<version>`, for example `3.0.0`
5. **Publishes docs** - Builds the docs and publishes them to HexDocs

### Manual Publishing

Start the workflow from the Actions tab of the repository (`workflow_dispatch`). It does the same steps.

## Version Management

### Semantic Versioning

Dream follows [Semantic Versioning](https://semver.org/):

- **MAJOR** (1.0.0 → 2.0.0) - Breaking changes
- **MINOR** (1.0.0 → 1.1.0) - New features (backward compatible)
- **PATCH** (1.0.0 → 1.0.1) - Bug fixes (backward compatible)

### Updating the Version

1. **Edit `gleam.toml`**:
   ```toml
   version = "3.0.1"
   ```

2. **Update `CHANGELOG.md`** and the release notes in `releases/`.

3. **Merge the change to `main`**. The workflow publishes the new version.

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

## Troubleshooting

### Version Not Publishing

**Check:**
- Is the version in `gleam.toml` different from the published versions?
- Did the build, the tests and the snippet check pass?
- Is `HEX_API_KEY` configured correctly?
- Check GitHub Actions logs for errors

### Duplicate Version Error

If Hex rejects a publish because the version already exists:
- Bump to the next version
- Check if someone else already published this version

## Related Documentation

- [Contributing Guide](index.md) - General contribution guidelines
- [Design Principles](../reference/design-principles.md) - Code quality standards
- [Architecture](../reference/architecture.md) - How modules fit together
