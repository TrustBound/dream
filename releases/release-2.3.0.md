# Dream 2.3.0 Release Notes

**Release Date:** December 1, 2025

Dream 2.3.0 upgrades to `dream_test` for a better testing experience, and fixes two router bugs that were discovered during the migration.

## Key Highlights

- 🧪 **Test Framework Upgrade** - Switched to `dream_test` for BDD-style testing with process isolation
- 🐛 **Router Parameter Fix** - Parameters now returned in correct path order
- 🔧 **Extension Pattern Fix** - Patterns like `/products.{json,xml}` now work correctly
- 📚 **Testing Documentation** - Complete rewrite for `dream_test` framework

## Why We Switched to dream_test

[dream_test](https://hexdocs.pm/dream_test/) provides features that `gleeunit` doesn't offer:

| Feature | What You Get |
|---------|--------------|
| **BDD-style syntax** | `describe`/`it` blocks that read like documentation |
| **Process isolation** | Each test runs in its own BEAM process |
| **Lifecycle hooks** | `before_each`, `after_each`, `before_all`, `after_all` |
| **Chainable matchers** | `should() \|> be_ok() \|> equal(expected)` |
| **Parallel execution** | Tests run concurrently across cores |
| **Crash isolation** | One test crashing doesn't affect others |
| **Timeout protection** | Hanging tests get killed automatically |

## What's Changed

### Test Framework Migration

Replaced `gleeunit` with [`dream_test`](https://hexdocs.pm/dream_test/) across all 21 test files:

**Before (gleeunit):**
```gleam
pub fn my_test_test() {
  my_function()
  |> should.equal(expected)
}
```

**After (dream_test):**
```gleam
pub fn tests() -> UnitTest {
  describe("my_module", [
    describe("my_function", [
      it("does X when Y", fn() {
        // Arrange
        let input = create_input()

        // Act
        let result = my_function(input)

        // Assert
        result
        |> should()
        |> equal(expected)
        |> or_fail_with("Expected X")
      }),
    ]),
  ])
}
```

**New Infrastructure:**
- 21 custom matchers in `test/matchers/` for cleaner assertions
- Reusable fixtures in `test/fixtures/` (request, response, handler, hooks)
- Process isolation for all 239 tests
- Self-identifying benchmark output for parallel execution

### Router Bug Fixes

**Parameter Ordering Fixed:**

Parameters are now returned in the order they appear in the path:

```gleam
// Route: /users/:user_id/posts/:post_id
// Request: /users/1/posts/2

// Before (2.2.0): [("post_id", "2"), ("user_id", "1")]  <- WRONG!
// After (2.3.0):  [("user_id", "1"), ("post_id", "2")]  <- Correct
```

**Extension Pattern Matching Fixed:**

Added `LiteralExtension` segment type for patterns like `/products.{json,xml}`:

```gleam
// Route definition
route(Get, "/products.{json,xml}", products_controller, [])

// Before (2.2.0): /products.json -> No match
// After (2.3.0):  /products.json -> Match!
```

## Documentation Updates

- Rewrote `docs/guides/testing.md` - Complete guide for `dream_test`
- Rewrote `docs/contributing/testing.md` - Contributor testing guidelines
- Updated streaming guide test examples

## Upgrading

Update your dependencies:

```toml
[dependencies]
dream = ">= 2.3.0 and < 3.0.0"
```

Then run:
```bash
gleam deps download
```

### Migration Notes

**If you depended on reversed parameter order:**

If your code was working around the reversed parameter order bug, you'll need to update it. The correct order is now returned.

**If you had extension patterns that weren't matching:**

Routes like `/products.{json,xml}` now work as expected. No code changes needed unless you had workarounds.

## Internal Changes

- Removed `gleeunit` dependency
- Added `dream_test >= 1.0.3` dev dependency
- Added `dream_http_client >= 2.1.1` dev dependency (for test server polling)
- New `LiteralExtension` segment type in router trie

## Testing

All 239 tests pass with the new framework:

```
Summary: 239 run, 0 failed, 239 passed
```

Test categories:
- Router: 85 tests (routing, params, wildcards, extensions, middleware)
- HTTP: 98 tests (request, response, headers, cookies, validation)
- Server: 24 tests (mist handler, request, response, lifecycle)
- Streaming: 18 tests (body parsing, middleware, error handling)
- Benchmarks: 6 tests (router performance)

## Documentation

- [dream](https://hexdocs.pm/dream) - v2.3.0
- [dream_test](https://hexdocs.pm/dream_test) - Testing framework docs
- [Testing Guide](https://github.com/TrustBound/dream/blob/main/docs/guides/testing.md)

## Community

- 📖 [Full Documentation](https://github.com/TrustBound/dream/tree/main/docs)
- 💬 [Discussions](https://github.com/TrustBound/dream/discussions)
- 🐛 [Report Issues](https://github.com/TrustBound/dream/issues)
- 🤝 [Contributing Guide](https://github.com/TrustBound/dream/blob/main/CONTRIBUTING.md)

---

**Full Changelog:** [CHANGELOG.md](https://github.com/TrustBound/dream/blob/main/CHANGELOG.md)
