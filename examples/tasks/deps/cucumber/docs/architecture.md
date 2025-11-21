# Cucumber Architecture

This document provides an overview of the Cucumber implementation architecture, explaining the core components and how they interact.

## Core Components

```
Cucumber
  ├── Discovery (Feature/Step Finding)
  ├── Gherkin (Parser)
  ├── Expression (Parameter Matching)
  ├── Compiler (Test Generation)
  ├── Runtime (Step Execution)
  └── StepError (Error Reporting)
```

### Discovery System

The discovery system automatically finds and loads feature files and step definitions:

```elixir
Discovery.discover()
  ├── Scans for features (test/features/**/*.feature)
  ├── Loads step definitions (test/features/step_definitions/**/*.exs)
  └── Returns: %{features: [...], step_registry: %{...}}
```

### Gherkin Parser

The Gherkin parser is responsible for parsing `.feature` files into a structured format that can be executed. It handles the syntax of Gherkin, including:

- Feature declarations
- Scenario outlines
- Backgrounds
- Steps (Given, When, Then)
- Tables and doc strings
- Tags

The parser produces an Abstract Syntax Tree (AST) that represents the structure of the feature file.

```elixir
# Simplified representation of the Gherkin parser flow
Feature File (Text) → Lexer → Tokens → Parser → AST
```

### Expression Engine

The Expression engine is responsible for matching step text against step definitions. It supports:

- Regular expressions
- Cucumber expressions (a simplified syntax with parameter types)
- Parameter conversion (string to typed values)

```elixir
defmodule Cucumber.Expression do
  # Converts a cucumber expression into a regex and parameter converters
  def compile(pattern) do
    # Transforms {string}, {int}, etc. into regex patterns
    # Returns {regex, converters}
  end

  # Matches text against a compiled expression
  def match(text, {regex, converters}) do
    # Returns {:match, args} or :no_match
  end
end
```

### Compiler

The compiler generates ExUnit test modules from discovered features:

```elixir
Compiler.compile_features!()
  ├── For each feature file:
  │   ├── Generates a test module
  │   ├── Creates setup from Background
  │   ├── Creates test cases from Scenarios
  │   └── Adds appropriate tags
  └── Compiles modules into memory
```

### Runtime

The runtime executes steps during test runs:

```elixir
Runtime.execute_step(context, step, step_registry)
  ├── Finds matching step definition
  ├── Prepares context with args, datatables, docstrings
  ├── Executes step function
  └── Processes return value
```

### StepDefinition Macro

The StepDefinition module provides the DSL for defining steps:

```elixir
defmodule MySteps do
  use Cucumber.StepDefinition

  step "pattern", context do
    # implementation
  end
end
```

## Execution Flow

1. **Discovery Phase** (at compile time)
   - `Cucumber.compile_features!()` is called in test_helper.exs
   - Discovery system finds all features and step definitions
   - Step registry is built with pattern → module mappings

2. **Compilation Phase**
   - For each feature, a test module is generated
   - Background steps become setup blocks
   - Scenarios become test cases
   - Tags are added for filtering

3. **Execution Phase** (at runtime)
   - ExUnit runs the generated test modules
   - Each test executes its steps via Runtime
   - Context is passed between steps
   - Errors are reported with helpful messages

## Data Flow

```
Feature File → Parser → AST
                          ↓
Step Files → Discovery → Registry
                          ↓
                      Compiler → Test Modules
                                      ↓
                                  ExUnit → Results
```

## Key Design Decisions

### Auto-Discovery
- Features and steps are automatically discovered
- No need to explicitly wire features to test modules
- Follows Ruby Cucumber's convention-over-configuration approach

### ExUnit Integration
- Generated tests are standard ExUnit test modules
- Full support for ExUnit features (tags, setup, async)
- Works with existing test tooling

### Runtime Compilation
- Tests are generated at runtime when `mix test` runs
- Allows for dynamic test generation
- No generated files to manage

### Context Management
- ExUnit context is used directly
- Background steps modify context in setup
- Each step can read and modify context

## Error Handling

Cucumber provides enhanced error messages with rich context:

1. **Undefined Steps**: Shows the exact step text with clickable file:line references and suggests implementation
2. **Step Failures**: Displays comprehensive error information including:
   - The failing step text with proper formatting
   - Clickable file:line reference to the scenario location (e.g., `test/features/example.feature:25`)
   - Visual step execution history with ✓ for passed and ✗ for failed steps
   - Formatted assertion errors extracted from ExUnit
   - Properly indented HTML output for PhoenixTest errors
   - Full stack traces for debugging
3. **Duplicate Steps**: Detected at load time with file/line information

The StepError module handles all error formatting, ensuring consistent and helpful error messages throughout the framework.

## Extensibility

The architecture supports several extension points:

1. **Custom Parameter Types**: Add new parameter types to Expression
2. **Custom Formatters**: Create custom output formats
3. **Hooks**: Before/after scenario hooks (via ExUnit setup/teardown)
4. **Step Libraries**: Create reusable step definition modules