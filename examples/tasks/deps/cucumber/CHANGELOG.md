# Changelog

## v0.4.1 (2025-06-06)

### New Features

- **Enhanced Error Formatting**: Significantly improved error messages for better debugging experience
  - Added scenario line numbers to error messages with clickable file:line format (e.g., `test/features/example.feature:9`)
  - Display contextual information including feature file path and scenario name
  - Show step execution history with clear pass/fail indicators
  - Improved PhoenixTest HTML element formatting with proper indentation
  - Better assertion error extraction and formatting for readability
  - Preserve stack traces with reraise for comprehensive debugging

### Internal Improvements

- Added comprehensive test coverage for error formatting scenarios
- Added unit tests for StepError module covering all error cases
- Added tests for Runtime error handling and formatting

## v0.4.0 (2025-05-28)

### New Features

- **Hooks Support**: Added before/after scenario hooks for setup and teardown
  - Define hooks in `test/features/support/` files
  - Global hooks run for all scenarios
  - Tag-filtered hooks run only for matching scenarios (e.g., `@database`)
  - Hooks can modify test context
  - Support for async scenarios
  - Auto-discovery of support files

### Documentation

- Added comprehensive hooks documentation guide
- Updated README with hooks feature
- Added practical examples for database setup, authentication, and performance monitoring

### Examples

- Added database setup example showing selective setup with `@database` tag
- Demonstrates how to avoid unnecessary setup for tests that don't need it

## v0.3.1 (2025-05-28)

### New Features

- **Async Test Execution**: Added support for concurrent test execution using the `@async` tag
  - Features marked with `@async` run concurrently with other async tests
  - Improves test suite performance for independent features
  - Safe to use with Ecto SQL sandbox in shared mode
  - Comprehensive documentation added

### Documentation

- Updated README with async feature documentation
- Enhanced feature files guide with `@async` tag usage
- Added async examples to getting started guide

## v0.3.0 (2025-05-28)

### Complete Architecture Redesign

This release completely redesigns the Cucumber library to follow Ruby Cucumber conventions with auto-discovery of features and step definitions.

#### Breaking Changes

1. **Auto-Discovery Architecture**
   - Tests are now auto-discovered - no need for explicit test modules
   - Feature files must be in `test/features/`
   - Step definitions must be in `test/features/step_definitions/`
   - Support files can be in `test/features/support/`
   - Just call `Cucumber.compile_features!()` in `test_helper.exs`

2. **New Step Definition Syntax**
   - Use `step` macro instead of `defstep`
   - Step definitions now use `use Cucumber.StepDefinition`
   - No more `use Cucumber, feature: "..."`

3. **Simplified API**
   - Main module only exports `compile_features!/1`
   - Step definitions are registered automatically
   - Background steps become ExUnit setup blocks

#### New Features

1. **Ruby Cucumber Compatibility**
   - Directory structure matches Ruby Cucumber conventions
   - Configurable paths using glob patterns
   - One ExUnit test module generated per feature file

2. **Better Integration**
   - Seamless `mix test` integration
   - ExUnit tags work as expected
   - Standard ExUnit context for state management

#### Migration from v0.2.0

1. Move your test files:
   ```
   # Old structure
   test/my_feature_test.exs

   # New structure
   test/features/my_feature.feature
   test/features/step_definitions/my_steps.exs
   ```

2. Update step definitions:
   ```elixir
   # Old
   defmodule MyFeatureTest do
     use Cucumber, feature: "my_feature.feature"

     defstep "I do something", context do
       {:ok, context}
     end
   end

   # New
   defmodule MySteps do
     use Cucumber.StepDefinition

     step "I do something", context do
       {:ok, context}
     end
   end
   ```

3. Update test_helper.exs:
   ```elixir
   # Old
   ExUnit.start()

   # New
   ExUnit.start()
   Cucumber.compile_features!()
   ```

## v0.2.0 (2025-05-23)

 New Features

  1. Shared Steps Support (Major Feature)
    - Added Cucumber.SharedSteps module for creating reusable step definitions
    - Allows step definitions to be defined in separate modules and imported
    - Supports composition of step libraries across test files
    - Maintains proper error reporting with accurate line numbers
    - Full test coverage with integration tests

  Breaking Changes

  1. Step Return Value Handling (Aligns with ExUnit)
    - Maps now merge into context instead of replacing it
    - Removed support for nil return values
    - Removed catch-all for arbitrary return values - now raises clear errors
    - Added support for keyword list return values
    - Valid returns: :ok, map, keyword_list, {:ok, map_or_keyword_list}, {:error, reason}

  Improvements

  1. Code Quality
    - Eliminated major duplication in Gherkin parser (68 lines removed, 16% reduction)
    - Replaced all List.first(context.args) with idiomatic pattern matching
    - Refactored to meet Credo strict standards
    - Improved documentation and examples
  2. Developer Experience
    - Better error messages for invalid step return values
    - More idiomatic Elixir patterns throughout
    - Cleaner API that matches ExUnit conventions

  Infrastructure

  1. Release Automation
    - Added scripts/release.sh for automated releases
    - Improved release process documentation

  Migration Guide

  For v0.1.0 users upgrading to v0.2.0:

  1. Step return values:
    - Change nil returns to :ok
    - Ensure maps are being merged (not replaced) as expected
    - Remove any non-standard return values
  2. Pattern matching:
    - Update List.first(context.args) to %{args: [var]} = context

## v0.1.0 (2024-05-13)

* Initial release
* Core features:
  * Gherkin parser with Background, Scenario, Step support
  * Cucumber expressions with parameter types ({string}, {int}, {float}, {word})
  * Data tables and docstring support
  * Tag filtering
  * Context passing between steps
  * Detailed error reporting
