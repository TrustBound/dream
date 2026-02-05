# Dream 2.3.2 Release Notes

**Release Date:** February 4, 2026

This release focuses on startup clarity and smoother local testing.

## Key Highlights

- **Fail-fast startup**: Servers now report a clear error when a port is already in use
- **Local test parity with CI**: One Makefile target prepares the integration databases
- **Cleaner server startup flow**: Internal helpers keep the public API simple

## Thanks

Thanks to [daniellionel01](https://github.com/daniellionel01) for reporting the issue.

## Fixed

Dream now detects port conflicts before starting the Mist server and returns a
direct, actionable error message. No more “it started” when it didn’t.

## Added

A new `setup-integration-dbs` target prepares the example databases and
applies migrations, matching CI’s database setup steps.

## Upgrading

Update your dependencies:

```toml
[dependencies]
dream = ">= 2.3.2 and < 3.0.0"
```

Then run:

```bash
gleam deps download
```

## Documentation

- [dream](https://hexdocs.pm/dream) - v2.3.2

---
