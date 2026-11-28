# Publishing Strategy

**How Dream is published to Hex.pm**

This document explains how the `dream` package gets to Hex.pm.

## Overview

- **One package**: This repository publishes the `dream` package only
- **Automated workflow**: GitHub Actions publishes when a maintainer pushes a version tag, for example `3.0.0`
- **Manual start**: Maintainers can start the workflow by hand with a tag, for example to finish a release

## Modules

Each Dream module has its own repository, its own version and its own release workflow: [dream_config](https://github.com/TrustBound/dream_config), [dream_ets](https://github.com/TrustBound/dream_ets), [dream_http_client](https://github.com/TrustBound/dream_http_client), [dream_json](https://github.com/TrustBound/dream_json), [dream_mock_server](https://github.com/TrustBound/dream_mock_server), [dream_opensearch](https://github.com/TrustBound/dream_opensearch) and [dream_postgres](https://github.com/TrustBound/dream_postgres). Read the contributing guide of a module to release it.

## Publishing Process

### Automatic Publishing

A merge to `main` does not publish. A pushed version tag publishes. The tag is the version itself, for example `3.0.0`, not `v3.0.0`.

To release a version, do these steps in this order:

1. Set the release date in `releases/release-<version>.md` and in `CHANGELOG.md`.
2. Merge the release to `main`.
3. Push the tag `<version>` on the merged commit. Run `git fetch origin main` first, so that `origin/main` has the merge:

   ```bash illustration
   git tag 3.0.1 origin/main
   git push origin 3.0.1
   ```

4. The "Publish to Hex" workflow (`.github/workflows/publish.yml`) publishes the version to Hex. Then it creates the GitHub release from the release notes file.

The workflow does these steps:

1. **Preflight checks** - Runs `.github/scripts/release-preflight.sh` with the tag. The script stops the release before anything is published when one of these is not true:
   - The tag is a bare version `X.Y.Z`
   - The tag is equal to the `version` in `gleam.toml`
   - The tagged commit is on `main`
   - `gleam.toml` has no path or git dependency
   - `releases/release-<version>.md` exists and has a real release date
   - `CHANGELOG.md` has the section `## [<version>]`, and its heading does not say `Unreleased`
2. **Checks the version** - Asks Hex one time if the version is published already. If it is, the workflow skips the build and the publish
3. **Builds and tests** - Runs `gleam build`, `make test-unit` and `make check-snippets`
4. **Publishes to Hex** - Runs `gleam publish --yes`
5. **Publishes docs** - Builds the docs and publishes them to HexDocs
6. **Creates the GitHub release** - Uses `releases/release-<version>.md` as the release text. If the release exists, the workflow does nothing

You can run the preflight checks on your machine before you push the tag. Run them after `git tag` and before `git push`:

```bash illustration
git checkout 3.0.1
bash .github/scripts/release-preflight.sh 3.0.1
```

### Manual Publishing

Start the workflow from the Actions tab of the repository (`workflow_dispatch`). Give the version tag, for example `3.0.1`. The tag must exist on GitHub. The workflow does the same steps.

If the version is on Hex already, the workflow only creates the GitHub release when it is missing. Use this to finish a release that Hex held for approval. See [Release Waits for Approval on Hex](#release-waits-for-approval-on-hex).

## Version Management

### Semantic Versioning

Dream follows [Semantic Versioning](https://semver.org/):

- **MAJOR** (1.0.0 → 2.0.0) - Breaking changes
- **MINOR** (1.0.0 → 1.1.0) - New features (backward compatible)
- **PATCH** (1.0.0 → 1.0.1) - Bug fixes (backward compatible)

### Updating the Version

1. **Edit `gleam.toml`**:
   ```toml illustration
   version = "3.0.1"
   ```

2. **Update `CHANGELOG.md`** and the release notes in `releases/`.

3. **Set the release date** in `releases/release-<version>.md` and in the `CHANGELOG.md` heading, for example `## [3.0.1] - 2026-11-23`.

4. **Merge the change to `main`**. The merge does not publish.

5. **Push the tag** for the version. Run `git fetch origin main` first. The workflow publishes the new version and creates the GitHub release:

   ```bash illustration
   git tag 3.0.1 origin/main
   git push origin 3.0.1
   ```

## Release Notes Template

Each release has a release notes file, `releases/release-<version>.md`. Dream, `dream_test`, `dream_snippets` and each module use the same template, so a reader finds the same part in the same place in every package.

The file has these parts, in this order:

1. The title: `# <Name> <version> Release Notes`, with the version of the file name
2. The line `**Release Date:**` with the date, or `not released yet (draft)` before the release
3. A short summary: what the release does, and why it is a major, minor or patch version
4. `## Key Highlights`: one bullet for each main change
5. `## What's New`: one `###` section for each new thing or change
6. `## Deprecated`, `## Removed`, `## Bug Fixes` and `## Known Limits`: only the ones that apply, in this order
7. `## Testing`: the number of tests, the result, the time, and the machine
8. `## Upgrading`: the dependency lines, then `### Migration Guide` with one numbered step for each change that can affect a project. The first release of a package has `## Installing` in its place
9. `## Acknowledgements`: only when the release has some
10. `## Documentation`: links to the docs of this version
11. `## Community`: links to discussions, issues and the contributing guide

A skeleton:

```markdown
# Dream 3.0.0 Release Notes

**Release Date:** not released yet (draft)

What this release does, in two or three sentences.

## Key Highlights

## What's New

## Bug Fixes

## Testing

## Upgrading

### Migration Guide

## Documentation

## Community
```

Rules for the text:

- Every fact is also in `CHANGELOG.md`
- Every Gleam code block is a tested snippet with its badge. See [Contributing](contributing.md)
- Use no other `##` section. Put other content under `## What's New`

The snippet check (`make check-snippets`) fails when a release notes file from version 3.0.0 on does not follow this template.

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
- Did you push the tag? A merge to `main` does not publish
- Is the tag the bare version, for example `3.0.1` and not `v3.0.1`?
- Did the preflight checks pass? Each failure prints an `Error:` line and a `Fix:` line. Run `bash .github/scripts/release-preflight.sh <version>` on your machine to see the same result
- Is the version in `gleam.toml` different from the published versions?
- Did the build, the tests and the snippet check pass?
- Is `HEX_API_KEY` configured correctly?
- Check GitHub Actions logs for errors

### Tag on the Wrong Commit

If the preflight check says that the tagged commit is not on `main`, or the tag does not match `gleam.toml`, move the tag. Delete the tag, then push it again on the merged commit:

```bash illustration
git push origin :refs/tags/3.0.1
git tag -d 3.0.1
git fetch origin main
git tag 3.0.1 origin/main
git push origin 3.0.1
```

Do this only when the version is not on Hex yet.

### Release Waits for Approval on Hex

Hex can hold a release for approval (a "staged" release), for example the first release of a new package. Then `gleam publish` prints success, but Hex does not show the version yet. The workflow does not create the GitHub release in this case. It ends successfully with a notice.

To finish the release:

1. Approve the release on Hex.
2. Start the workflow by hand with the tag, for example `3.0.1`.

The workflow sees the version on Hex. It skips the publish and creates the GitHub release.

### Duplicate Version Error

If Hex rejects a publish because the version already exists:
- Bump to the next version
- Check if someone else already published this version

## Related Documentation

- [Contributing Guide](index.md) - General contribution guidelines
- [Design Principles](../reference/design-principles.md) - Code quality standards
- [Architecture](../reference/architecture.md) - How modules fit together
