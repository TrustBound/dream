# Contributing to Dream

Thank you for your interest in contributing to Dream! We're excited to have you here.

## Quick Links

📖 **[Full Contributing Guide](docs/contributing/contributing.md)** - Detailed contribution guidelines  
🧪 **[Testing Guide](docs/contributing/testing.md)** - Running Dream's test suite  
📦 **[Publishing Strategy](docs/contributing/publishing.md)** - Module versioning and releases  
✍️ **[Tone Guide](docs/contributing/tone-guide.md)** - Documentation writing style  
🤝 **[Code of Conduct](CODE_OF_CONDUCT.md)** - Community standards  
🔒 **[Security Policy](SECURITY.md)** - Reporting security vulnerabilities

## Quick Start for Contributors

### Prerequisites

- Gleam 1.7.0 or later
- Erlang/OTP 27 or later
- PostgreSQL 16 (for database examples)
- Elixir 1.15+ (for integration tests)

### Development Setup

1. **Fork and clone:**
   ```bash
   git clone https://github.com/YOUR-USERNAME/dream.git
   cd dream
   ```

2. **Run tests:**
   ```bash
   make test                # All tests (unit + integration)
   make test-unit           # Unit tests only (core + modules)
   make test-integration    # Integration tests only (modules + examples, requires PostgreSQL)
   ```

3. **Make your changes:**
   - Write code following our [design principles](docs/reference/design-principles.md)
   - Add tests for new functionality
   - Update documentation as needed

4. **Format and verify:**
   ```bash
   gleam format             # Format code
   make test                # Ensure tests pass
   ```

5. **Submit a pull request:**
   - Clear description of changes
   - Reference any related issues
   - Ensure CI passes

## What Can I Contribute?

### 🐛 Bug Reports
Found a bug? [Open an issue](https://github.com/TrustBound/dream/issues/new?template=bug_report.md) with:
- Clear description of the problem
- Steps to reproduce
- Expected vs actual behavior
- Your environment (Gleam version, OS, etc.)

### 💡 Feature Requests
Have an idea? [Open an issue](https://github.com/TrustBound/dream/issues/new?template=feature_request.md) with:
- Clear use case
- Proposed API or behavior
- Why this fits Dream's philosophy

### 📝 Documentation
Documentation improvements are always welcome:
- Fix typos or unclear explanations
- Add examples
- Improve guides

### 🔧 Code Contributions
- Fix bugs
- Implement approved features
- Improve performance
- Add tests

## Code Standards

Dream follows strict coding standards. Please read:
- **[Design Principles](docs/reference/design-principles.md)** - The "why" behind Dream
- **[Naming Conventions](docs/reference/naming-conventions.md)** - Code style rules

Key principles:
- **No magic** - Everything explicit
- **No closures** - All dependencies are parameters
- **Full words** - No abbreviations (except standard ones)
- **100% test coverage** - For `src/dream/` code
- **Black box testing** - Test public interfaces only

## Development Workflow

1. **Create a branch:**
   ```bash
   git checkout -b feature/my-feature
   # or
   git checkout -b fix/issue-123
   ```

2. **Make focused commits:**
   ```bash
   git commit -m "Add user authentication middleware"
   ```

3. **Keep your fork updated:**
   ```bash
   git remote add upstream https://github.com/TrustBound/dream.git
   git fetch upstream
   git rebase upstream/main
   ```

4. **Push and create PR:**
   ```bash
   git push origin feature/my-feature
   ```

## Testing Requirements

All contributions must include tests:

- **Unit tests** - Fast, isolated, deterministic
- **Integration tests** - For examples with end-to-end scenarios
- **100% coverage** - For core Dream code in `src/dream/`

See the [Testing Guide](docs/contributing/testing.md) for details.

## Documentation Requirements

Update documentation for:
- New features (HexDocs + guides)
- API changes (update all references)
- Breaking changes (migration guide)

## Review Process

1. **Automated checks:**
   - Code formatting (`gleam format`)
   - Unit tests
   - Integration tests
   - No compiler warnings

2. **Manual review:**
   - Code quality
   - Tests coverage
   - Documentation
   - Fits Dream's philosophy

3. **Maintainer approval:**
   - At least one maintainer approval required
   - May request changes or clarification

## Getting Help

- **Questions?** [Open a discussion](https://github.com/TrustBound/dream/discussions)
- **Stuck?** Comment on your PR or issue
- **Security issue?** See [SECURITY.md](SECURITY.md)

## Recognition

All contributors are recognized in our documentation and release notes. Thank you for making Dream better! 🎉

## About Dream

Dream was created by [TrustBound](https://trustbound.ai), an AI security platform, to build our production SaaS. We needed a type-safe web toolkit that was explicit, composable, and ran on the BEAM for massive concurrency.

We built Dream, used it to build TrustBound, and open-sourced it under MIT license so others could benefit.

Dream is community-driven. TrustBound funds development, but contributions come from everyone. All decisions happen in public issues and discussions.

---

**Read more:** [Full Contributing Guide](docs/contributing/contributing.md)

