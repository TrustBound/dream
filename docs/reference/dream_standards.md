# dream_standards

**Authoritative Dream coding standards.**  
These are **rules**, not suggestions. Code that violates them is incorrect and must be fixed.

## 1. Philosophy

- Dream **is a library, not a framework**.
- Behavior **MUST be explicit**, not hidden in magic or globals.
- Code **MUST prioritize type safety** and correctness over cleverness.
- Code **MUST be simple and composable**.

## 2. Function & Module Naming

- Functions **MUST** follow the `{verb}_{noun}` pattern  
  (e.g. `create_router`, `handle_error`, `match_path`).
- Functions **MUST NOT** be prefixed with the module name.
  - ✅ `router.create_router()`  
  - ❌ `router.router_create_router()`
- Exceptions:
  - Builder APIs **MAY** use single verbs when the builder type makes context obvious:
    ```gleam
    builder
      |> method(Get)
      |> path("/users")
      |> handler(handle_users)
    ```
  - Factory-style constructors **MAY** use bare nouns when the meaning is unambiguous in context:
    ```gleam
    pub fn router() -> Router
    pub fn ok() -> Status
    ```

## 3. Dependencies & Closures

- Controllers, middleware, models, operations, and helpers **MUST** be **top-level named functions** with explicit parameters.
- Code **MUST NOT** hide dependencies (e.g. services, DB handles) in closures.

  ```gleam
  // Forbidden
  fn make_controller(db: Database) -> fn(Request) -> Response {
    fn(request) {
      query_database(db, request)
    }
  }
  ```

  ```gleam
  // Required pattern
  pub fn controller(request: Request, context: Context, services: Services) -> Response {
    let db = services.database
    query_database(db, request)
  }
  ```

- Closures **MAY ONLY** be used when a third‑party API strictly requires a specific callback shape and there is no alternative.

## 4. Error Handling

- Business logic **MUST** use `Result(success, error)` for recoverable errors.
- Code **MUST NOT** use exceptions for normal control flow.
- Errors **MUST NOT** be discarded with `_` (`Error(_)`, `Error(_err)`).
- Error cases **MUST** be bound to a named value and explicitly handled or converted:

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
- Domain-standard abbreviations (`http`, `url`, `id`, `json`, etc.) **ARE ALLOWED**.
- Single-letter identifiers **MUST** be restricted to:
  - Type parameters (`a`, `b`, `t`, …),
  - Very small local lambdas (1–2 lines),
  - Mathematical loops/coordinates.

## 6. Tests & Documentation

- Every new or changed **public function** **MUST**:
  - Have tests that exercise it through public APIs (black-box).
  - Have doc comments describing behavior and showing at least one example.
- Unit tests **MUST** be:
  - Fast, deterministic, and isolated from real DB/network/filesystem.
- Test function names **MUST** follow:

  `function_name_with_condition_returns_expected_result_test()`

## 7. Warnings & Unused Things

- Code that is part of Dream or Dream modules **MUST compile with zero warnings**.
- For each unused variable/parameter, authors **MUST** choose one of:
  - Implement missing behavior so it is used, **or**
  - Remove it and update all call sites.
- A leading `_` **MAY ONLY** be used when:
  - The value is mandated by an external interface and is truly unused,
  - The intent to ignore it is clear.

## 8. Control Flow & Structure

- Code **MUST NOT** contain deeply nested `case` expressions where simple refactoring can avoid them.
  - Complex flows **MUST** be decomposed into helper functions or expressed using `result.try` / `option` helpers.
- Modules **MUST** stay focused. When a file grows too large or multi-purpose, it **MUST** be split into smaller modules grouped by responsibility (e.g. `router/matcher`, `http/headers`).

## 9. Forbidden Patterns (Hard Rules)

The following patterns are **FORBIDDEN**:

- Capturing services/DB/config/etc. in closures instead of passing explicitly.
- Naming functions with vague or generic names (`do_it`, `helper`, `run`, `utils`, etc.).
- Discarding errors with `_` patterns.
- Introducing hidden behavior via framework-like magic or global state.
- Using ad‑hoc abbreviations for variables/parameters (`req`, `cfg`, `svc`, etc.).
- Testing private functions directly instead of going through public APIs.
- Adding or changing public APIs without:
  - Doc comments, **and**
  - Corresponding tests.
