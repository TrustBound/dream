# Unit Testing Guide

This document outlines the unit testing standards and practices for the Dream framework.

## Testing Framework

Dream uses **Gleeunit**, the standard Gleam testing framework, for all unit tests.

### Setup

Add Gleeunit as a development dependency in `gleam.toml`:

```toml
[dev-dependencies]
gleeunit = "~> 0.5"
```

### Test Structure

**Tests must be placed in the `test/` directory** - they cannot be co-located with their implementation files. Gleeunit automatically discovers test functions that:
- Are public functions (`pub fn`)
- Have names ending with `_test`
- Are located in the `test/` directory

**Why a separate test directory?**

- Clear separation between production code and test code
- Gleeunit's automatic test discovery requires tests in `test/`
- Aligns with Gleam community conventions
- Keeps `src/` focused on production code only
- Makes it easier to exclude test code from production builds

**Test File Organization:**

Mirror the structure of `src/` in `test/` to keep tests organized:

```
src/
  dream/
    core/
      router.gleam
      statuses.gleam
test/
  dream/
    core/
      router_test.gleam      # Tests for router.gleam
      statuses_test.gleam     # Tests for statuses.gleam
```

### Test Entry Point

Create a `test/your_project.gleam` file with:

```gleam
import gleeunit

pub fn main() {
  gleeunit.main()
}
```

### Running Tests

Run all tests with:

```bash
gleam test
```

### Test Coverage

**Gleeunit does not provide built-in test coverage analysis.** While Dream compiles to Erlang and could theoretically use Erlang's `cover` tool, coverage collection is not currently integrated into the test workflow.

#### Coverage Requirements

Per our coverage requirements (see [Coverage Requirements](#coverage-requirements) section), we maintain **100% test coverage** of all functions in `src/dream`. Coverage is verified through code review and ensuring all public functions have corresponding tests.

**Note:** Since we use black box testing, coverage should be achieved through testing public interfaces only. If a private function isn't reachable through public functions, it's dead code and should be removed.

### Assertions

Use `gleeunit/should` for assertions:

```gleam
import gleeunit/should

pub fn example_test() {
  let result = some_function()
  result |> should.equal(expected_value)
}
```

### Optional: Glacier for Incremental Testing

For faster development feedback, consider using **Glacier**, which builds on Gleeunit to provide incremental testing (only runs tests affected by code changes):

```toml
[dev-dependencies]
gleeunit = "~> 0.5"
glacier = "~> 0.1"
```

Replace `gleeunit` import with `glacier` in your test entry point:

```gleam
import glacier

pub fn main() {
  glacier.main()
}
```

Run with Glacier enabled:

```bash
gleam test -- --glacier
```

## Core Testing Philosophy

### Black Box Testing Only

**We use black box testing exclusively.** This means:

- ✅ **Tests interact only with public interfaces** - Test public functions, not internal implementation details
- ✅ **Focus on inputs, outputs, and behavior** - Verify that given inputs produce expected outputs and behavior
- ❌ **Do not test internal implementation details** - Avoid testing private functions, internal state, or implementation-specific logic

**Why Black Box Testing?**

- Tests remain stable when internal implementation changes
- Tests document how the public API is used
- Tests focus on what the code does, not how it does it
- Easier to refactor without breaking tests

## Unit Test Requirements

All unit tests must meet these criteria:

### ✅ Isolated

- **No external dependencies** - Tests do not rely on databases, file systems, network calls, or external services
- **Independent execution** - Each test can run independently without relying on other tests
- **No shared state** - Tests do not modify or depend on shared mutable state

### ✅ Fast

- **No network latency** - Tests complete in milliseconds, not seconds
- **No I/O operations** - No file system access, database queries, or external API calls
- **Immediate feedback** - Developers can run the full test suite frequently during development

### ✅ Deterministic

- **Same result every time** - Running the same test multiple times produces identical results
- **No randomness** - Tests do not depend on random values or unpredictable behavior
- **Predictable outcomes** - Same inputs always produce same outputs

### ✅ Reliable

- **Not affected by network issues** - Tests pass regardless of network connectivity
- **Not affected by external state** - Tests pass regardless of what's happening outside the test environment
- **Consistent across environments** - Tests pass on all developers' machines and CI/CD

## Coverage Requirements

### 100% Coverage of `src/dream`

**All functions in `src/dream` must have 100% test coverage.**

- Every public function must be tested
- Every code path must be exercised
- Edge cases and error conditions must be tested

### Coverage Validation Rule

**If any private function isn't being called through the public functions, it means we have not achieved 100% coverage.**

- Private functions should only exist if they're used by public functions
- If a private function is not reachable through public functions, it's dead code and should be removed
- Achieving 100% coverage ensures all code paths are exercised through public interfaces

## Dependency Injection

### All Dependencies Must Be Mockable

**All dependencies should be mockable via dependency injection. Closures should not be used in this project for this reason.**

- **Explicit Parameters** - Dependencies are passed as explicit parameters, not hidden in closures
- **Mockable** - All dependencies can be replaced with mock implementations in tests
- **No Closures** - We avoid closures because they hide dependencies and make testing difficult

**Why Dependency Injection?**

- Enables testing without real dependencies
- Makes dependencies explicit and visible
- Allows easy substitution of mock implementations
- Follows Dream's design principles (see [DESIGN_PRINCIPLES.md](DESIGN_PRINCIPLES.md))

**Example - Good (Dependency Injection)**:

```gleam
// Function receives database as explicit parameter
pub fn create_user(db: DatabaseService, name: String) -> Result(User, Error) {
  // Use db parameter
}

// Test can pass mock database
pub fn create_user_with_valid_name_returns_user_test() {
  let mock_db = mock_database()
  let result = create_user(mock_db, "Alice")
  // Assert...
}
```

**Example - Bad (Hidden Dependency)**:

```gleam
// ❌ Closure hides database dependency
pub fn create_user_factory(db: DatabaseService) -> fn(String) -> Result(User, Error) {
  fn(name) {
    // db is captured in closure - harder to test
  }
}
```

## Test Quality

### All Tests Must Be Meaningful

- **Test real behavior** - Tests verify actual functionality, not trivial operations
- **Test edge cases** - Cover error conditions, boundary values, and unusual inputs
- **Test failure modes** - Verify that errors are handled correctly
- **Avoid trivial tests** - Don't test getters/setters or simple data transformations unless they contain logic

### Tests Serve Dual Role

**Tests serve a dual role as an example of usage of public functions.**

- Tests demonstrate how to use the public API
- Tests show expected behavior for different inputs
- Tests document edge cases and error handling
- New developers can learn the API by reading tests

## Test Naming Convention

Test names should be descriptive and explain what is tested. Use the pattern:

```
<function_name>_<condition>_<expected_result>_test()
```

### ✅ Good Names

```gleam
// Clear what condition is tested and what result is expected
pub fn create_widget_with_valid_data_returns_widget_id_test()

pub fn create_widget_with_empty_name_returns_error_test()

pub fn update_widget_that_does_not_exist_returns_not_found_test()

pub fn parse_path_with_single_parameter_extracts_parameter_test()

pub fn match_route_with_exact_path_returns_handler_test()

pub fn match_route_with_no_matching_path_returns_not_found_test()

pub fn convert_client_error_to_status_with_not_found_returns_404_test()
```

### ❌ Bad Names

```gleam
// Vague - doesn't explain what's tested
pub fn test_create_widget()

// Too generic - could test anything
pub fn widget_test()

// Meaningless - provides no information
pub fn test1()

// Doesn't specify condition or expected result
pub fn create_widget_test()

// Uses "test" prefix instead of suffix
pub fn test_widget_creation()
```

## Arrange, Act, Assert Pattern

All tests should follow the **Arrange, Act, Assert** (AAA) pattern:

1. **Arrange** - Set up test data, mocks, and preconditions
2. **Act** - Execute the function being tested
3. **Assert** - Verify the expected outcome

### Example - Good (AAA Pattern)

```gleam
import gleeunit/should

pub fn create_widget_with_valid_data_returns_widget_id_test() {
  // Arrange: Set up test data and mocks
  let mock_db = mock_database()
  let widget_name = "My Widget"
  let widget_data = WidgetData(name: widget_name)
  
  // Act: Execute the function under test
  let result = create_widget(mock_db, widget_data)
  
  // Assert: Verify expected outcome
  case result {
    Ok(widget) -> {
      widget.id |> should.equal("widget-123")
      widget.name |> should.equal(widget_name)
    }
    Error(_) -> {
      should.fail("Expected Ok, got Error")
    }
  }
}
```

### Example - Bad (Mixed Concerns)

```gleam
// ❌ Mixed arrange/act/assert - hard to read
pub fn create_widget_test() {
  let result = create_widget(mock_database(), WidgetData(name: "Test"))
  result |> should.equal(Ok(Widget(id: "widget-123", name: "Test")))
  // Missing clear separation
}
```

## Complete Examples

### Example 1: Testing a Pure Function

```gleam
// Source: dream/core/http/statuses.gleam
pub fn ok() -> Success {
  OkStatus(code: 200, message: "OK", description: "...")
}

// Test
import gleeunit/should

pub fn ok_returns_status_with_code_200_test() {
  // Arrange: No setup needed for pure function
  
  // Act: Call the function
  let status = statuses.ok()
  
  // Assert: Verify the result
  case status {
    OkStatus(code, message, _) -> {
      code |> should.equal(200)
      message |> should.equal("OK")
    }
  }
}
```

### Example 2: Testing with Dependency Injection

```gleam
// Source: dream/core/router.gleam (example)
pub fn add_route(
  router: Router(context),
  route: Route(context),
) -> Router(context) {
  Router(routes: [route, ..router.routes])
}

// Test
import gleeunit/should

pub fn add_route_to_empty_router_creates_router_with_one_route_test() {
  // Arrange: Set up test data
  let empty_router = router
  let test_route = Route(
    method: Get,
    path: "/test",
    handler: fn(_) { text_response(ok_status(), "test") },
    middleware: [],
  )
  
  // Act: Execute the function
  let result = add_route(empty_router, test_route)
  
  // Assert: Verify the route was added
  list.length(result.routes) |> should.equal(1)
  list.head(result.routes) |> should.equal(option.Some(test_route))
}

pub fn add_route_to_router_with_existing_routes_appends_route_test() {
  // Arrange: Set up router with existing routes
  let existing_route = Route(
    method: Get,
    path: "/existing",
    handler: fn(_) { text_response(ok_status(), "existing") },
    middleware: [],
  )
  let router_with_routes = Router(routes: [existing_route])
  let new_route = Route(
    method: Post,
    path: "/new",
    handler: fn(_) { text_response(created_status(), "new") },
    middleware: [],
  )
  
  // Act: Execute the function
  let result = add_route(router_with_routes, new_route)
  
  // Assert: Verify the route was added at the beginning
  list.length(result.routes) |> should.equal(2)
  case list.head(result.routes) {
    option.Some(route) -> {
      route.path |> should.equal("/new")
    }
    option.None -> {
      should.fail("Expected route at head")
    }
  }
}
```

### Example 3: Testing Error Conditions

```gleam
// Example function that validates input
pub fn validate_email(email: String) -> Result(String, ValidationError) {
  case string.contains(email, "@") {
    True -> Ok(email)
    False -> Error(InvalidEmailFormat)
  }
}

// Tests
import gleeunit/should

pub fn validate_email_with_valid_format_returns_email_test() {
  // Arrange
  let valid_email = "user@example.com"
  
  // Act
  let result = validate_email(valid_email)
  
  // Assert
  case result {
    Ok(email) -> email |> should.equal(valid_email)
    Error(_) -> should.fail("Expected Ok for valid email")
  }
}

pub fn validate_email_with_missing_at_sign_returns_error_test() {
  // Arrange
  let invalid_email = "userexample.com"
  
  // Act
  let result = validate_email(invalid_email)
  
  // Assert
  case result {
    Ok(_) -> should.fail("Expected Error for invalid email")
    Error(error) -> {
      case error {
        InvalidEmailFormat -> Nil
        _ -> should.fail("Expected InvalidEmailFormat error")
      }
    }
  }
}

pub fn validate_email_with_empty_string_returns_error_test() {
  // Arrange
  let empty_email = ""
  
  // Act
  let result = validate_email(empty_email)
  
  // Assert
  case result {
    Ok(_) -> should.fail("Expected Error for empty email")
    Error(_) -> Nil // Valid - empty string doesn't contain "@"
  }
}
```

### Example 4: Testing with Mocks

```gleam
// Example service function
pub fn get_user_by_id(db: DatabaseService, user_id: String) -> Result(User, DatabaseError) {
  db.query("SELECT * FROM users WHERE id = ?", [user_id])
}

// Mock database for testing
fn mock_database() -> DatabaseService {
  DatabaseService(
    query: fn(query, params) {
      case params {
        ["user-123"] -> Ok([User(id: "user-123", name: "Alice")])
        _ -> Error(UserNotFound)
      }
    },
    execute: fn(_) { Ok(0) },
    transaction: fn(f) { f() },
  )
}

// Tests
import gleeunit/should

pub fn get_user_by_id_with_existing_user_returns_user_test() {
  // Arrange: Set up mock database
  let mock_db = mock_database()
  let user_id = "user-123"
  
  // Act: Execute the function
  let result = get_user_by_id(mock_db, user_id)
  
  // Assert: Verify the result
  case result {
    Ok(user) -> {
      user.id |> should.equal(user_id)
      user.name |> should.equal("Alice")
    }
    Error(_) -> should.fail("Expected Ok for existing user")
  }
}

pub fn get_user_by_id_with_non_existing_user_returns_error_test() {
  // Arrange: Set up mock database
  let mock_db = mock_database()
  let non_existing_id = "user-999"
  
  // Act: Execute the function
  let result = get_user_by_id(mock_db, non_existing_id)
  
  // Assert: Verify error is returned
  case result {
    Ok(_) -> should.fail("Expected Error for non-existing user")
    Error(error) -> {
      case error {
        UserNotFound -> Nil
        _ -> should.fail("Expected UserNotFound error")
      }
    }
  }
}
```

## Summary

When writing unit tests:

1. ✅ **Use black box testing** - Test public interfaces only
2. ✅ **Meet all requirements** - Isolated, fast, deterministic, reliable
3. ✅ **Achieve 100% coverage** - All functions in `src/dream` must be tested
4. ✅ **Use dependency injection** - Make all dependencies mockable
5. ✅ **Write meaningful tests** - Test real behavior and edge cases
6. ✅ **Follow naming conventions** - Descriptive names that explain what's tested
7. ✅ **Use AAA pattern** - Arrange, Act, Assert structure
8. ✅ **Document usage** - Tests serve as examples of API usage

**Remember**: Tests are documentation. Good tests help future developers understand how to use the code.

