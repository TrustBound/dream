# Contributing to Dream

Thanks for your interest in contributing! Dream is a community project and we welcome contributions.

## Philosophy

Before contributing, understand Dream's core philosophy:

- **Library, not framework** - Provide building blocks, not opinions
- **Explicit over implicit** - No magic, no hidden behavior
- **Simple over clever** - Code should be obvious
- **Type-safe** - Leverage Gleam's type system fully
- **No closures** - All dependencies explicit

Read [Design Principles](../reference/design-principles.md) for the full picture.

## Code Style

Follow the [Naming Conventions](../reference/naming-conventions.md):

- Functions: `{verb}_{noun}` pattern
- No module name prefixes
- Full words, no abbreviations (except standard ones like `id`, `http`, `json`)
- Builder pattern for configuration

Use `gleam format` before committing:

```bash
gleam format
```

## Testing

All code must have tests. Dream requires **100% test coverage** of `src/dream/`.

### Unit Tests

- Black box testing only (test public interfaces)
- No external dependencies (no database, network, files)
- Fast (milliseconds)
- Deterministic (same result every time)

See [Testing Guide](../guides/testing.md) for details.

### Running Tests

```bash
gleam test
```

### Test Naming

```gleam
pub fn function_name_with_condition_returns_expected_result_test()
```

Example:

```gleam
pub fn create_user_with_valid_data_returns_user_test()
pub fn create_user_with_empty_name_returns_error_test()
```

## Documentation

All public functions must have documentation comments:

```gleam
/// Creates a new router with no routes configured.
///
/// ## Example
///
/// ```gleam
/// import dream/router.{router}
///
/// let my_router = router
/// ```
pub fn router() -> Router(context, services) {
  Router(routes: [])
}
```

Include:
- Brief description of what the function does
- Example usage with imports
- Any important notes or caveats

### Code Blocks in READMEs and Guides

Every Gleam code block in a README, guide or reference page comes from a snippet file that the tests compile and run. A code block with no tested snippet can be wrong, and nobody finds out until a reader tries it.

1. Write the code in `test/snippets/<name>.gleam` (or in the module's own `test/snippets/`).
2. Run it from `test/snippets_test.gleam`, so that the tests fail when the snippet breaks.
3. Copy the code into the doc.
4. Give the code block a heading, and put a "tested snippet" badge at the right of the heading. The badge links to the snippet file at the release tag of the version you are writing for, for example `blob/2.5.0/`. Each published version then links to its own code, and the link keeps working when a snippet moves later.

```markdown
### JSON APIs <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/readme_json_api.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
```

Use the full GitHub URL, not a relative path. HexDocs and Hex show the README without the repository, so a relative link goes nowhere.

A code block can be a whole snippet file, or a range of lines from one. For an excerpt, the badge link ends in a GitHub line range, for example `https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/naming_create.gleam#L8-L10`. The block shows those lines byte for byte, with the same indent. The snippet file around the excerpt still compiles and has a test.

An example of what not to do is real Dream code too. It compiles and runs in a tested snippet. Don't show a function that doesn't exist, and don't put Gleam code in a `text` block or in prose to get past the check. The text next to the block says why the code is bad.

Examples in doc comments (`///`) are code blocks too. HexDocs shows them to every reader, so each one comes from a tested snippet in the same way, with a heading and the badge inside the comment, directly above the example.

When you find a code block that doesn't follow this, change it in the same pull request.

### Contributing to Documentation

For writing or improving user-facing documentation (guides, tutorials, examples), see the [Documentation Contributing Guide](index.md). It covers:

- Voice and tone guidelines
- Documentation structure
- Testing documentation
- Review process

## Pull Request Process

1. **Fork the repository**

2. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make your changes**
   - Write code
   - Write tests
   - Write documentation
   - Run `gleam format`

4. **Verify everything works**
   ```bash
   gleam check    # Type checking
   gleam test     # All tests pass
   gleam format   # Code formatted
   ```

5. **Commit with clear messages**
   ```bash
   git commit -m "feat: add middleware chaining support"
   ```

   Use conventional commits:
   - `feat:` - New feature
   - `fix:` - Bug fix
   - `docs:` - Documentation only
   - `refactor:` - Code change that neither fixes a bug nor adds a feature
   - `test:` - Adding or updating tests
   - `chore:` - Maintenance tasks

6. **Push and create PR**
   ```bash
   git push origin feature/your-feature-name
   ```

7. **Wait for review**
   - Address feedback
   - Keep PR scope focused
   - Be patient and respectful

## What to Contribute

### Good First Issues

Look for issues labeled `good-first-issue`. These are specifically chosen for newcomers.

### Bug Reports

Found a bug? Open an issue with:
- What you expected to happen
- What actually happened
- Minimal code to reproduce
- Your environment (Gleam version, OS)

### Feature Requests

Have an idea? Open an issue describing:
- The problem you're trying to solve
- Your proposed solution
- Why it fits Dream's philosophy
- Example API/usage

We may say no if it doesn't align with Dream's goals. That's okay.

### Documentation

Documentation improvements are always welcome:
- Fix typos
- Clarify confusing sections
- Add examples
- Improve organization

## Project Structure

```
dream/
  src/
    dream/
      core/            # Core types (Request, Response, Router, etc.)
      servers/         # Server adapters (Mist)
      services/        # Service helpers (Postgres, etc.)
      utilities/       # Utilities (HTTP client, JSON, etc.)
      validators/      # Validators (JSON, etc.)
  test/
    dream/             # Tests mirror src/ structure
  docs/                # Documentation
    tutorials/         # Step-by-step guides
    guides/            # Topic-focused how-tos
    reference/         # Technical reference
  examples/        # Working example applications (each is its own Gleam project)
```

## Publishing (Maintainers Only)

Dream and its modules are published to Hex.pm. Only maintainers can publish.

### Core Dream Package

For publishing the main `dream` package, see the [Publishing Strategy](publishing.md).

### Dream Modules

Dream modules are published automatically via GitHub Actions when version numbers change. See the [Publishing Strategy](publishing.md) for details.

**Quick version bump:**
1. Update `modules/<module_name>/gleam.toml` version
2. Commit and push to `main`
3. GitHub Actions automatically publishes if version changed

### Semantic Versioning

Dream and all modules follow [Semantic Versioning](https://semver.org/):

- **MAJOR** (1.0.0 → 2.0.0) - Breaking changes
- **MINOR** (1.0.0 → 1.1.0) - New features (backward compatible)
- **PATCH** (1.0.0 → 1.0.1) - Bug fixes (backward compatible)

## Code of Conduct

Be respectful. Be professional. Be kind.

We're all here to build something useful. Treat others how you'd want to be treated.

- ✅ Constructive criticism
- ✅ Helping newcomers
- ✅ Assuming good intent

- ❌ Personal attacks
- ❌ Harassment
- ❌ Disrespectful behavior

Violations will result in removal from the project.

## Questions?

- Open an issue for feature discussions
- Check existing issues before opening new ones
- Be patient - maintainers are volunteers

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

**Thank you for contributing to Dream!**

