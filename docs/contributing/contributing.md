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

1. Write the code in `test/snippets/<name>.gleam`.
2. Run it from `test/snippets_test.gleam`, so that the tests fail when the snippet breaks.
3. Copy the code into the doc.
4. Give the code block a heading, and put a "tested snippet" badge at the right of the heading. The badge links to the snippet file at the release tag of the version you are writing for, for example `blob/3.0.0/`. Each published version then links to its own code, and the link keeps working when a snippet moves later.

```markdown
### JSON APIs <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/readme_json_api.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
```

Use the full GitHub URL, not a relative path. HexDocs and Hex show the README without the repository, so a relative link goes nowhere.

Each example in the root `README.md` has a second badge, the guide badge. It links to the docs section that shows the same example, so a reader can go from the short README example to its full explanation. Put the tested snippet badge first, then one space, then the guide badge, all on the heading line:

```markdown
### JSON APIs <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/readme_json_api.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a> <a href="https://github.com/TrustBound/dream/blob/3.0.0/docs/guides/rest-api.md#return-a-user-as-json-"><img align="right" alt="Guide" src="https://img.shields.io/badge/%F0%9F%93%96_read-guide-blue.svg?style=flat-square"></a>
```

The check makes sure of these things for a guide badge:

- The link is a `blob` link of this repository, at the tag of the `version` in `gleam.toml`.
- The link goes to a `.md` file under `docs/`. The `guides` setting in `[tools.dream_snippets]` sets this directory.
- The file exists, and the link ends with `#<anchor>`. The anchor is the GitHub anchor of a heading in that file: the heading text in lowercase, with each character removed that is not a letter, a digit, a space, a hyphen or an underscore, and each space changed to a hyphen. The space between the heading text and its badge also becomes a hyphen, so the anchor of a heading with a badge ends with a hyphen: `### Return a user as JSON` with a badge has the anchor `return-a-user-as-json-`.
- The docs file shows the same example, with a tested snippet badge that links to the same snippet file. The line range can be different.

Only the root README has guide badges. A heading in a guide, the changelog, the release notes or a doc comment has only the tested snippet badge. When you add an example to the README, add it to a docs page first, then link the guide badge to that section.

A code block can be a whole snippet file, or a range of lines from one. For an excerpt, the badge link ends in a GitHub line range, for example `https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/naming_create.gleam#L8-L10`. The block shows those lines byte for byte, with the same indent. The snippet file around the excerpt still compiles and has a test.

An example of what not to do is real Dream code too. It compiles and runs in a tested snippet. Don't show a function that doesn't exist, and don't put Gleam code in a `text` block or in prose to get past the check. The text next to the block says why the code is bad.

Examples in doc comments (`///`) are code blocks too. HexDocs shows them to every reader, so each one comes from a tested snippet in the same way, with a heading and the badge inside the comment, directly above the example.

When you find a code block that doesn't follow this, change it in the same pull request.

Release notes and changelog entries follow this rule from version 3.0.0 on. The check reads `releases/release-<version>.md` when the version in the file name is 3.0.0 or later, and the `## [Unreleased]` section and the `## [<version>]` sections for 3.0.0 or later in `CHANGELOG.md`. It skips older notes and older changelog sections. They show code that was right for their own version.

Each Dream module, such as `dream_ets`, lives in its own repository and has its own snippet check. The badges in a module README link at that repository and at the version tag of the module, for example `https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/basic_operations.gleam`.

An upgrade guide shows how code changed. The old code does not compile on the new version, so it cannot be a tested snippet. Show each change as a `diff` block instead. The block is an excerpt of the real git diff of one file in this repository, between the last release tag and the new version:

1. Find a file in the repository that made the change, for example with `git diff 2.4.1 -- examples/ src/ test/snippets/`.
2. Copy the `--- a/<path>` and `+++ b/<path>` lines, then the diff lines that show the change. Keep the `-`, `+` and space at the start of each line. You can keep or leave out the `@@` hunk headers. Lines with no hunk header between them must come from one hunk, in order, with no line left out.
3. Give the block a heading, and put a "tested diff" badge at the right of the heading. The badge links to the file in GitHub's compare view. The link names the old tag, the new tag (the `version` in `gleam.toml`), and the anchor `#diff-` followed by the SHA-256 hex digest of the file's path. Get the digest with `printf '%s' <path> | shasum -a 256`.

```markdown
#### Read a stream from `request.body` <a href="https://github.com/TrustBound/dream/compare/2.4.1...3.0.0#diff-96161bd1d29b10b5817d71e3db6be67d9a8494e6ea36bc113379cb3b2743ce32"><img align="right" alt="Tested diff" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-diff-lightgreen.svg?style=flat-square"></a>
```

Don't write a "before" by hand. When no file in the repository made the change, show the new code as a tested snippet, and name the old form in inline code in the text next to it.

Run the check by hand from the repository root:

```bash
make check-snippets
```

It runs `gleam run -m dream_snippets`. The check is the [`dream_snippets`](https://github.com/TrustBound/dream_snippets) package, a dev dependency of Dream. Its settings are in the `[tools.dream_snippets]` table of `gleam.toml`. The check reads `README.md`, `SECURITY.md`, each `.md` file in `docs/` and `examples/`, and the doc comments in `src/`. It also reads the release notes and changelog sections from 3.0.0 on. It does not use the network. For a `diff` block it runs `git diff <old tag> -- <path>`, so it needs the release tags in your clone. It fails when:

- a Gleam code block has no heading with the badge directly above it (one blank line between is allowed)
- the badge is not in the exact format shown above
- the badge links to another repository or host
- the tag in the link is not the `version` in `gleam.toml`
- the linked file does not exist
- the line range is malformed, reversed, or past the end of the file
- the code block is not the same as the linked file or line range
- the code block uses the old `🧪 Tested source` line
- a README example has no guide badge, or the guide badge is not in the exact format or place
- the guide badge does not link to a heading in a `.md` file under `docs/` at the release tag, or that file does not show the same snippet
- a heading outside the README has a guide badge
- a code fence with another language, or with no language, holds Gleam code
- a `diff` block has no heading with the tested diff badge, or the badge is not in the exact format
- the diff badge link is not a compare link in this repository, its new tag is not the `version` in `gleam.toml`, or its anchor is not the digest of the path in the block
- the old tag is not in your clone (run `git fetch --tags`, because a shallow clone has no tags)
- the file has no diff between the old tag and the working tree, or a line of the block is not in that diff in that place

It prints each problem as `file:line: reason`, then a summary line. `make check`, the pre-commit hook, CI and the publish workflows also run it.

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

```text
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

Dream is published to Hex.pm. Only maintainers can publish. See the [Publishing Strategy](publishing.md).

### Dream Modules

Each Dream module has its own repository and its own releases, for example [dream_http_client](https://github.com/TrustBound/dream_http_client). The [Publishing Strategy](publishing.md#modules) lists them. Release a module from its own repository.

### Semantic Versioning

Dream follows [Semantic Versioning](https://semver.org/):

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

