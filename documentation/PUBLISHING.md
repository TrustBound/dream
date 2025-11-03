# Publishing Dream to Hex

This guide explains how to publish the Dream package to Hex.pm, the package manager for Gleam and Erlang.

## Prerequisites

- Ensure you have a Hex.pm account (create one at https://hex.pm if needed)
- Ensure your code compiles (`gleam check`)
- Ensure tests pass (if you have any)
- Have write access to the GitHub repository

## Package Configuration

The `gleam.toml` file has been configured with:
- Package name: `dream`
- Description: "A composable web library for Gleam/BEAM"
- License: MIT
- Repository links (GitHub)
- Documentation links (HexDocs)

## Steps to Publish

### 1. Before Publishing - Important Checks

**Verify Package Name Availability:**
- Check that the package name "dream" is available on Hex.pm
- Visit https://hex.pm/packages/dream to check availability

**Check What Will Be Published:**
```bash
# Dry run to see what will be included
gleam publish --dry-run
```

**Note:** The `examples/` directory in `src/examples/` should not be included in the published package. If `gleam publish` includes them, consider moving examples outside of `src/` or configuring exclusions.

### 2. First Time Publishing (Interactive)

Run the publish command:
```bash
gleam publish
```

**First Time Process:**
1. Enter your Hex.pm username when prompted
2. Enter your Hex.pm password when prompted
3. Create a local password to encrypt the API token (you'll use this for future publishes)
4. Gleam will check for issues:
   - Namespace conflicts
   - Missing documentation
   - Other validation checks
5. Review any warnings or prompts
6. Confirm to publish

**What Happens:**
- Gleam creates a long-lived API token
- Encrypts it with your local password
- Stores it on your filesystem
- Publishes the package to Hex.pm

### 3. Subsequent Publishing

For future releases:
```bash
gleam publish
```

**Process:**
1. Enter your local password (not your Hex password)
2. Gleam uses the stored encrypted API token
3. Review and confirm

### 4. Automated/CI Publishing

For continuous integration environments:

```bash
HEXPM_USER=your_username HEXPM_PASS=your_password gleam publish --yes
```

**Environment Variables:**
- `HEXPM_USER`: Your Hex.pm username
- `HEXPM_PASS`: Your Hex.pm password
- `--yes`: Auto-accept confirmation prompts

### 5. Publishing Documentation

After publishing the package, publish HTML documentation to HexDocs:

```bash
gleam docs publish
```

This publishes documentation to https://hexdocs.pm/dream

**Note:** Documentation is generated from module comments and documentation files. Ensure your code has proper `///` documentation comments.

## Version Management

### Updating Version

For new releases:

1. **Update version in `gleam.toml`:**
   ```toml
   version = "1.0.1"  # Use semantic versioning
   ```

2. **Create a release commit:**
   ```bash
   git add gleam.toml
   git commit -m "chore: bump version to 1.0.1"
   git tag v1.0.1
   git push origin main --tags
   ```

3. **Publish:**
   ```bash
   gleam publish
   ```

### Semantic Versioning

Follow semantic versioning (MAJOR.MINOR.PATCH):
- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

## Package Ownership

### Transferring Ownership

To transfer package ownership to another Hex account:

```bash
gleam hex owner transfer <new_owner> <package_name>
```

### Adding Owners

To add additional owners who can publish:

```bash
gleam hex owner add <username> dream
```

## Troubleshooting

### Common Issues

**"Package name already taken":**
- Choose a different package name
- Or contact the current owner if you need that name

**"Namespace conflicts":**
- Ensure all modules are properly namespaced under `dream/`
- Check for any top-level module conflicts

**"Missing documentation":**
- Add `///` documentation comments to public functions
- Ensure modules have documentation

**"Build fails":**
- Run `gleam check` to identify compilation errors
- Ensure all dependencies are properly specified

### Checking Package Status

View your published package:
- Hex.pm: https://hex.pm/packages/dream
- HexDocs: https://hexdocs.pm/dream

## Best Practices

1. **Always test locally** before publishing
2. **Update CHANGELOG.md** with changes for each release
3. **Tag releases** in git with version numbers
4. **Document breaking changes** clearly
5. **Follow semantic versioning** strictly
6. **Keep dependencies up to date** but pinned to compatible versions

## Current Package Status

**Package Name:** dream  
**Current Version:** 0.0.1  
**License:** MIT  
**Repository:** https://github.com/FileStory/dream  
**Documentation:** https://hexdocs.pm/dream

## Quick Reference

```bash
# Check package before publishing
gleam publish --dry-run

# Publish package (interactive)
gleam publish

# Publish documentation
gleam docs publish

# Automated publish (CI)
HEXPM_USER=user HEXPM_PASS=pass gleam publish --yes

# Check package status
gleam hex info dream
```

