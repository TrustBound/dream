# dream_standards: rules for agents

Authoritative Dream coding standards for agents. These are **rules**, not suggestions. Code that violates them is incorrect and must be changed.

## 1. Philosophy

- Dream **is a library, not a framework**.
- Behavior **MUST be explicit**, never hidden behind magic or global state.
- Code **MUST** favor type safety and correctness over cleverness.
- Code **MUST** stay simple and composable.

## 2. Function & Module Naming

- Functions **MUST** follow the `{verb}_{noun}` pattern.
  - Examples: `create_router`, `handle_error`, `match_path`, `parse_cookie_string`.
- Functions **MUST NOT** be prefixed with the module name.
  - ✅ `router.create_router()`
  - ❌ `router.router_create_router()`
- Builder-style APIs **MAY** use short verbs when the builder type is obvious:
  ```gleam
  builder
    |> method(Get)
    |> path("/users")
    |> handler(handle_users)
  ```
- Factory constructors **MAY** use bare nouns when the meaning is unambiguous in context:
  ```gleam
  pub fn router() -> Router
  pub fn ok() -> Status
  ```

## 3. Dependencies & Closures

- Controllers, middleware, models, operations, and helpers **MUST** be top-level named functions with explicit parameters.
- Code **MUST NOT** hide dependencies (services, databases, config, clients, etc.) in closures.

  ```gleam
  // FORBIDDEN
  fn make_controller(db: Database) -> fn(Request) -> Response {
    fn(request) {
      query_database(db, request)
    }
  }
  ```

  ```gleam
  // REQUIRED PATTERN
  pub fn controller(request: Request, context: Context, services: Services) -> Response {
    let db = services.database
    query_database(db, request)
  }
  ```

- Agents **MUST** pass dependencies explicitly through parameters or the `Services` type.
- Closures **MAY ONLY** be used when a third‑party API strictly requires a specific callback shape and there is no alternative.

## 4. Error Handling

- Business logic **MUST** use `Result(success, error)` for recoverable errors.
- Code **MUST NOT** use exceptions for normal control flow.
- Errors **MUST NOT** be discarded with `_` (`Error(_)`, `Error(_err)`, `_`).
- Error values **MUST** be bound to a named variable and handled or converted explicitly:

  ```gleam
  case result {
    Ok(value) -> value
    Error(reason) -> handle_error(reason)
  }
  ```

## 5. Variables & Parameters

- Variable and parameter names **MUST** use full words, not ad‑hoc abbreviations:
  - ✅ `request`, `response`, `user_id`, `services`
  - ❌ `req`, `resp`, `uid`, `svc`
- Standard domain abbreviations **ARE ALLOWED** (e.g. `http`, `url`, `id`, `json`).
- Single-letter identifiers **MUST** be limited to:
  - Generic type parameters (`a`, `b`, `t`, ...),
  - Very small lambdas (1–2 lines),
  - Mathematical indices/coordinates (`i`, `j`, `x`, `y`).

## 6. Tests & Documentation

- Every new or changed **public function** **MUST** have:
  - At least one test exercising it through public APIs (black-box, not private helpers).
  - Doc comments explaining behavior, plus at least one example.
- Unit tests **MUST** be fast, deterministic, and isolated from real DB/network/filesystem.
- Test function names **MUST** follow:

  `function_name_with_condition_returns_expected_result_test()`

## 7. Warnings & Unused Things

- Dream code and Dream modules **MUST** compile with zero warnings.
- For every unused variable/parameter, agents **MUST** choose one of:
  - Implement missing behavior so the value is used, or
  - Remove the parameter/variable and update all call sites.
- A leading `_` **MAY ONLY** be used when:
  - The value is required by an external interface and truly unused, and
  - The intent to ignore it is clear.

## 8. Control Flow & Structure

- Code **MUST NOT** use deeply nested `case` expressions when simple refactoring can avoid them.
  - Complex flows **MUST** be split into helper functions or re-expressed using `result.try` / `option` helpers.
- Modules **MUST** stay focused on a clear responsibility.
  - When a file becomes large or multi-purpose, it **MUST** be split into smaller modules grouped by concept (e.g. `router/matcher`, `http/headers`).

## 9. Forbidden Patterns (Hard Rules)

Agents **MUST NOT** introduce any of the following patterns:

- Capturing `Services`, DB handles, config, or other dependencies in closures.
- Naming functions with vague or generic names (`do_it`, `helper`, `run`, `utils`, etc.).
- Throwing away errors using `_` or ignoring them without explicit handling.
- Adding hidden behavior through framework-style magic or global state.
- Using ad‑hoc abbreviations for identifiers (`req`, `cfg`, `svc`, etc.).
- Testing private functions directly; tests **MUST** go through public APIs.
- Adding or changing public APIs without both:
  - Doc comments, **and**
  - Corresponding tests.
