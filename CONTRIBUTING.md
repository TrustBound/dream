# Contributing to Dream

Thank you for your interest in contributing to Dream! This file is a **GitHub entry point**. The canonical, detailed documentation lives under `docs/`.

## Start Here

- 📖 **Full Contributing Guide:** `docs/contributing/contributing.md`
- 🧪 **Testing Guide:** `docs/contributing/testing.md`
- 📦 **Publishing Strategy:** `docs/contributing/publishing.md`
- ✍️ **Docs & Tone Guide:** `docs/contributing/index.md`, `docs/contributing/tone-guide.md`
- 🤝 **Code of Conduct:** `CODE_OF_CONDUCT.md`
- 🔒 **Security Policy:** `SECURITY.md`

## Quick Start

### Prerequisites

- Gleam 1.7.0 or later
- Erlang/OTP 27 or later

### Local Setup

```bash
git clone https://github.com/YOUR-USERNAME/dream.git
cd dream

# Run tests (unit + integration)
make test

# Or just unit tests
make test-unit
```

### Making Changes

1. Create a branch:
   ```bash
   git checkout -b feature/my-feature
   ```
2. Make focused changes:
   - Follow our [design principles](docs/reference/design-principles.md)
   - Follow [naming conventions](docs/reference/naming-conventions.md)
   - Add tests and docs for new behavior
3. Format and verify:
   ```bash
   gleam format
   make test
   ```
4. Push and open a PR on GitHub.

For the full process (coverage requirements, review details, publishing, etc.), see the **Full Contributing Guide** in `docs/contributing/contributing.md`.

