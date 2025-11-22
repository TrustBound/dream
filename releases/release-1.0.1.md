# Dream 1.0.1 Release Notes

**Release Date:** November 22, 2025

Dream 1.0.1 is a patch release that fixes logo display issues on Hex.pm for all Dream packages. This ensures proper branding and visual consistency when viewing package documentation on Hex.pm.

## What's Fixed

### Logo Display on Hex.pm

Fixed broken logo images on Hex.pm package pages by updating README files to use full GitHub URLs instead of relative paths.

**Changed in all packages:**
- Main `dream` package
- `dream_config`
- `dream_ets`
- `dream_http_client`
- `dream_json`
- `dream_opensearch`
- `dream_postgres`

**Technical Details:**
- Updated logo image source from relative path (`ricky_and_lucy.png`) to full GitHub URL (`https://raw.githubusercontent.com/TrustBound/dream/main/ricky_and_lucy.png`)
- Added Dream logo to all module README files for consistent branding across the ecosystem
- Logos now display correctly on Hex.pm, GitHub, and any other platform rendering the README

## Upgrading

Update your dependencies to 1.0.1:

```toml
[dependencies]
dream = ">= 1.0.1 and < 2.0.0"
dream_config = ">= 1.0.1 and < 2.0.0"
dream_ets = ">= 1.0.1 and < 2.0.0"
dream_http_client = ">= 1.0.1 and < 2.0.0"
dream_json = ">= 1.0.1 and < 2.0.0"
dream_opensearch = ">= 1.0.1 and < 2.0.0"
dream_postgres = ">= 1.0.1 and < 2.0.0"
```

Then run:
```bash
gleam deps download
```

**Note:** This is a documentation-only release. No code changes were made. Upgrading is optional but recommended for consistency with published documentation.

## No Breaking Changes

This release contains no breaking changes or code modifications. All functionality remains identical to 1.0.0.

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

