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

Dream's tests use [dream_test](https://hexdocs.pm/dream_test/), not `_test` functions. Name the `describe` group for the function, and name each `it` for the result it expects and the condition:

#### Name a test for its result and condition <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/contributing_test_naming.gleam#L12-L21"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
fn to_status_code_tests() -> UnitTest {
  describe("to_status_code", [
    it("returns 404 for NotFound", fn() {
      error.to_status_code(NotFound("User not found"))
      |> should()
      |> equal(404)
      |> or_fail_with("Expected 404")
    }),
  ])
}
```

Example:

#### Name the tests of one function <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/contributing_test_naming.gleam#L23-L38"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
fn message_tests() -> UnitTest {
  describe("message", [
    it("returns the message of a BadRequest", fn() {
      error.message(BadRequest("Invalid email format"))
      |> should()
      |> equal("Invalid email format")
      |> or_fail_with("Expected the BadRequest message")
    }),
    it("returns the message of an InternalServerError", fn() {
      error.message(InternalServerError("Database connection failed"))
      |> should()
      |> equal("Database connection failed")
      |> or_fail_with("Expected the InternalServerError message")
    }),
  ])
}
```

## Documentation

All public functions must have documentation comments:

### Document a public function <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/contributing_documentation.gleam#L5-L21"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Creates a plain-text response that greets a person by name.
///
/// ## Example
///
/// ### Greet a person <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/contributing_documentation_example.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/response.{type Response}
/// import snippets/contributing_documentation.{create_greeting_response}
///
/// pub fn greet_ada() -> Response {
///   create_greeting_response("Ada")
/// }
/// ```
pub fn create_greeting_response(name: String) -> Response {
  text_response(200, "Hello, " <> name <> "!")
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
4. Give the code block a heading, and put a "tested snippet" badge at the right of the heading. The badge links to the snippet file at the release tag of the version you are writing for, for example `blob/3.0.0/`. Each published version then links to its own code, and the link keeps working when a snippet moves later.

```markdown
### JSON APIs <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/readme_json_api.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
```

Use the full GitHub URL, not a relative path. HexDocs and Hex show the README without the repository, so a relative link goes nowhere.

A code block can be a whole snippet file, or a range of lines from one. For an excerpt, the badge link ends in a GitHub line range, for example `https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/naming_create.gleam#L8-L10`. The block shows those lines byte for byte, with the same indent. The snippet file around the excerpt still compiles and has a test.

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

