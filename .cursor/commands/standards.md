# Dream Coding Standards

This document summarizes the most important Dream coding standards in a way that is easy for Cursor to apply automatically. When in doubt, prefer the repo docs under `docs/reference/`.

## Quick Rules for Cursor (READ FIRST)

When editing or generating Dream code, ALWAYS follow these rules:

1. **No hidden dependencies**
   - Do NOT capture `Services`, database handles, or other dependencies in closures.
   - Controllers, middleware, models, and helpers must be **named top-level functions** with explicit parameters.

2. **No nested `case` and no clever control flow**
   - Avoid deeply nested `case` expressions; instead, factor logic into small helper functions or use `result.try` / `option` helpers.
   - Prefer straightforward code over clever tricks.

3. **Semantic naming with `{verb}_{noun}`**
   - Use meaningful names like `create_router`, `get_header`, `handle_error`.
   - Do NOT prefix function names with the module name (`router.router_add_route` is invalid).
   - Use full-word variable names (`request`, `services`, `user_id`), not abbreviations (`req`, `svc`, `uid`).

4. **Explicit error handling**
   - Use `Result(success, error)` for business logic.
   - Never throw errors away with patterns like `Error(_)`; always bind and handle or intentionally document the decision.

5. **Testing, docs, warnings, and structure**
   - Any new or changed public function must have tests (black-box, via public APIs) and doc comments.
   - Core Dream code (`src/dream/`) is expected to be fully covered by tests.
   - Code should compile **with zero warnings**. For any unused variable, first decide:
     - Is this variable meant to be used (a sign something is unimplemented)? If so, implement the missing behavior.
     - Or should the variable be removed from the function signature? If so, update all call sites to match.
   - When files grow large, prefer splitting into **small, focused modules** with clear, semantic names that match their responsibility (e.g. `router/matcher`, `router/path_params`), keeping the directory structure logical and discoverable.

Details and rationale for these rules are below.

## Core Philosophy (High-Level Rules)

1. **Library, not framework** – Provide composable building blocks, not hidden framework magic.
2. **Explicit over implicit** – No global state, no magic registration, no hidden behavior.
3. **Simple over clever** – Prefer boring, obviously-correct code over clever tricks.
4. **Type-safe** – Lean on Gleam’s type system; use `Result` for recoverable errors.
5. **No closures for dependencies** – Dependencies must be explicit parameters, not captured.

## Function Naming (CRITICAL)

### Core Rule: `{verb}_{noun}` Pattern

- Functions normally follow the `{verb}_{noun}` pattern, where the verb describes the action and the noun describes what is being acted upon.
- Each prefix (`create_`, `get_`, `handle_`, etc.) has a **single, unambiguous purpose**.
- Do not invent new prefixes if an existing one already expresses the semantics.

### Module Namespace

The module name provides the namespace, so functions must **not** be prefixed with the module name.

✅ **Good:**
```gleam
import router

router.create_router()
router.route(my_router, method: Get, path: "/", controller: controller_fn, middleware: [])
```

❌ **Bad:**
```gleam
router.router_create_router()  // Redundant module prefix
router.router_add_route()      // Redundant module prefix
```

### Prefix Categories (Use These Semantics)

#### Creation & Construction

**`create_{noun}`** - Creates a new instance from scratch without using a builder pattern.
- Use when: Instantiating a type directly with constructor parameters or simple factory functions
- Examples: `create_router()`, `create_response(status)`, `create_cookie(name, value)`
- Do NOT use when: Building from a builder pattern (use `build_{noun}` instead)

**`build_{noun}`** - Constructs a final instance from a builder pattern.
- Use when: Converting a builder type into its final built type
- Examples: `build(builder: RouteBuilder)`, `build_response(builder: ResponseBuilder)`
- Do NOT use when: Creating instances directly (use `create_{noun}` instead)

#### Retrieval

**`get_{noun}`** - Retrieves a value from a collection by identifier/key.
- Use when: Looking up items in lists, maps, or other collections using a name, key, or identifier
- Examples: `get_header(headers, name)`, `get_cookie(cookies, name)`, `get_query_param(query, name)`
- Do NOT use when: Extracting a property from a single item (use `{noun}_name` or `{noun}_value` instead)

**`{noun}_name`** - Gets the name property of a single item.
- Use when: Extracting the name field from a single record/type instance
- Examples: `cookie_name(cookie)`, `header_name(header)`, `route_name(route)`
- Do NOT use when: Searching for an item in a collection (use `get_{noun}` instead)

**`{noun}_value`** - Gets the value property of a single item.
- Use when: Extracting the value field from a single record/type instance
- Examples: `cookie_value(cookie)`, `header_value(header)`
- Do NOT use when: Searching for an item in a collection (use `get_{noun}` instead)

#### Modification (Immutable)

**`set_{noun}`** - Replaces or overwrites an existing value in a collection.
- Use when: Updating a value that may already exist, replacing the old value if present
- Examples: `set_header(headers, name, value)`, `set_cookie(cookies, cookie)`, `set_config(config, key, value)`
- Do NOT use when: Adding a new item that may not exist (use `add_{noun}` instead)

**`add_{noun}`** - Adds a new item to a collection without removing existing items.
- Use when: Appending or inserting items into collections where duplicates are allowed or desired
- Examples: `add_header(headers, name, value)`, `route(router, method, path, controller, middleware)`, `add_middleware(builder, middleware)`
- Do NOT use when: Replacing an existing value (use `set_{noun}` instead)

**`remove_{noun}`** - Removes an item from a collection.
- Use when: Deleting items from collections by identifier/key
- Examples: `remove_header(headers, name)`, `remove_cookie(cookies, name)`, `remove_route(router, path)`

#### Type Conversion

**`convert_{from}_to_{to}`** - Converts between different types, especially when converting between external library types and internal types.
- Use when: Transforming between types that represent the same concept but are from different modules or libraries
- Examples: `convert_method(http_method)`, `convert_request_to_response(request)`, `convert_status_to_code(status)`
- Do NOT use when: Parsing from strings (use `parse_{noun}` instead) or formatting to strings (use `format_{noun}` instead)

**`parse_{noun}`** - Parses string or raw data into a structured type.
- Use when: Converting unstructured text or binary data into typed structures
- Examples: `parse_cookie_string(cookie_string)`, `parse_query_string(query)`, `parse_json(json_string)`
- Do NOT use when: Converting between two structured types (use `convert_{from}_to_{to}` instead)

**`format_{noun}`** - Formats a structured type into a string or raw data format.
- Use when: Converting typed structures into strings or bytes for output or transmission
- Examples: `format_cookie_header(cookie)`, `format_status_code(status)`, `format_query_string(params)`
- Do NOT use when: Converting between two structured types (use `convert_{from}_to_{to}` instead)

**`{from}_to_{to}`** - Short conversion form when the context makes the conversion clear.
- Use when: Converting between types where the relationship is obvious and the full `convert_{from}_to_{to}` would be verbose
- Examples: `method_to_string(method)`, `string_to_method(str)`, `status_to_code(status)`
- Do NOT use when: Converting between external library types (use `convert_{from}_to_{to}` instead)

#### Boolean Checks

**`is_{adjective}`** - Checks if an item has a specific property or state.
- Use when: Evaluating a characteristic or condition of a single item
- Examples: `is_method(request, method)`, `is_secure(cookie)`, `is_authenticated(user)`, `is_valid(response)`
- Do NOT use when: Checking if a collection contains an item (use `has_{noun}` instead)

**`has_{noun}`** - Checks if a collection contains an item or if an item has a component.
- Use when: Testing for presence or existence in collections or composite types
- Examples: `has_content_type(request, content_type)`, `has_header(headers, name)`, `has_cookie(cookies, name)`
- Do NOT use when: Checking a property of a single item (use `is_{adjective}` instead)

#### Request/Response Processing

**`handle_{noun}`** - Processes HTTP requests or responses, performing business logic or transformation.
- Use when: Implementing request handlers, middleware, or response processors that contain logic
- Examples: `handle_request(request)`, `handle_error(error)`, `handle_authentication(request)`
- Do NOT use when: Simply routing requests (use `route_{noun}` instead)

**`route_{noun}`** - Routes a request to the appropriate handler based on matching logic.
- Use when: Finding and dispatching requests to handlers based on path, method, or other criteria
- Examples: `route_request(router, request)`, `route_path(path, routes)`
- Do NOT use when: Processing request logic (use `handle_{noun}` instead)

**`match_{noun}`** - Matches a pattern against a value, returning a boolean or result.
- Use when: Testing if a value matches a pattern, path template, or condition
- Examples: `match_path(pattern, path)`, `match_method(allowed, method)`, `match_route(route, request)`
- Do NOT use when: Routing requests (use `route_{noun}` instead)

#### Error Handling

**`handle_{noun}_error`** - Handles a specific error type, converting it to a result or response.
- Use when: Implementing error recovery or transformation logic for specific error types
- Examples: `handle_parse_error(error)`, `handle_auth_error(error)`, `handle_validation_error(error)`
- Do NOT use when: Recovering from errors (use `recover_from_{noun}` instead)

**`recover_from_{noun}`** - Recovers from an error state, attempting to restore normal operation.
- Use when: Implementing retry logic or fallback mechanisms
- Examples: `recover_from_timeout(error)`, `recover_from_connection_error(error)`
- Do NOT use when: Handling errors without recovery (use `handle_{noun}_error` instead)

#### Authentication & Authorization

**`authenticate_{noun}`** - Verifies identity based on credentials or tokens.
- Use when: Validating user identity, checking passwords, or verifying tokens
- Examples: `authenticate_user(credentials)`, `authenticate_token(token)`, `authenticate_request(request)`
- Do NOT use when: Checking permissions (use `authorize_{noun}` or `check_{noun}_permission` instead)

**`authorize_{noun}`** - Checks if a user has permission to access a resource or perform an action.
- Use when: Verifying access rights for resources or operations
- Examples: `authorize_user(user, resource)`, `authorize_request(request, action)`
- Do NOT use when: Verifying identity (use `authenticate_{noun}` instead)

**`check_{noun}_permission`** - Checks a specific permission for a user or request.
- Use when: Testing for a particular permission flag or capability
- Examples: `check_user_permission(user, permission)`, `check_request_permission(request, permission)`
- Do NOT use when: Performing full authorization (use `authorize_{noun}` instead)

#### Validation

**`validate_{noun}`** - Validates data and returns a Result indicating success or failure with detailed errors.
- Use when: Performing comprehensive validation that may return multiple errors or detailed error information
- Examples: `validate_request(request)`, `validate_cookie(cookie)`, `validate_config(config)`
- Do NOT use when: Simple boolean checks (use `is_{adjective}` or `has_{noun}` instead)

#### Lifecycle Management

**`start_{noun}`** - Starts a service, process, or long-running operation.
- Use when: Initiating servers, background tasks, or services
- Examples: `start_server(config)`, `start_background_task(task)`
- Do NOT use when: Initializing resources (use `init_{noun}` instead)

**`stop_{noun}`** - Stops a service or process immediately.
- Use when: Halting services or processes without graceful cleanup
- Examples: `stop_server(server)`, `stop_task(handle)`
- Do NOT use when: Gracefully shutting down (use `shutdown_{noun}` instead)

**`init_{noun}`** - Initializes a resource or component with configuration.
- Use when: Setting up resources, loading configuration, or preparing for use
- Examples: `init_database(config)`, `init_logger(config)`, `init_services(config)`
- Do NOT use when: Starting services (use `start_{noun}` instead)

**`shutdown_{noun}`** - Gracefully shuts down a service, performing cleanup operations.
- Use when: Stopping services with proper cleanup, saving state, or closing connections
- Examples: `shutdown_server(server)`, `shutdown_database(database)`
- Do NOT use when: Immediate stopping (use `stop_{noun}` instead)

#### Serialization

**`serialize_{noun}`** - Converts a structured type into a serialized format (bytes or string).
- Use when: Encoding data for storage or transmission
- Examples: `serialize_response(response)`, `serialize_config(config)`, `serialize_user(user)`
- Do NOT use when: Formatting for display (use `format_{noun}` instead)

**`deserialize_{noun}`** - Converts serialized data (bytes or string) into a structured type.
- Use when: Decoding data from storage or transmission
- Examples: `deserialize_response(bytes)`, `deserialize_config(json)`, `deserialize_user(bytes)`
- Do NOT use when: Parsing from strings with complex structure (use `parse_{noun}` instead)

#### State Management

**`load_{noun}`** - Loads data from persistent storage by identifier.
- Use when: Retrieving data from databases, files, or other persistent storage
- Examples: `load_user(id)`, `load_config(path)`, `load_settings(key)`
- Do NOT use when: Retrieving from memory/cache (use `get_{noun}` instead)

**`save_{noun}`** - Saves data to persistent storage.
- Use when: Writing data to databases, files, or other persistent storage
- Examples: `save_user(user)`, `save_config(config, path)`
- Do NOT use when: Storing in memory (use `store_{noun}` instead)

**`store_{noun}`** - Stores data in memory or cache.
- Use when: Keeping data in memory, cache, or temporary storage
- Examples: `store_session(key, session)`, `store_cache(key, value)`
- Do NOT use when: Persisting to storage (use `save_{noun}` instead)

**`restore_{noun}`** - Restores data from a backup or checkpoint.
- Use when: Recovering from backups, checkpoints, or saved states
- Examples: `restore_database(backup_id)`, `restore_session(session_id)`
- Do NOT use when: Loading current data (use `load_{noun}` instead)

#### Response Builders

**`{type}_response`** - Creates a response of a specific content type.
- Use when: Constructing HTTP responses with specific content types or formats
- Examples: `text_response(status, body)`, `json_response(status, body)`, `html_response(status, body)`, `redirect_response(status, location)`, `empty_response(status)`
- Do NOT use when: Creating generic responses (use `create_response` instead)

### Exceptions

#### Builder Pattern Exception

For fluent builder APIs, simple action verbs without nouns are acceptable when the builder type provides context:

✅ **Acceptable:**
```gleam
builder
  |> method(Get)
  |> path("/")
  |> handler(fn(req) { ... })
  |> bind("localhost")
  |> listen(3000)
```

This exception applies only to:
- Builder pattern configuration methods
- When the builder type provides clear context
- When full names would be overly verbose

**Do NOT use this exception for:** General-purpose functions outside of builder patterns.

#### Factory Function Exception

For factory functions that create instances where context makes it unambiguous, `create_{noun}` can be shortened to just `{noun}`:

✅ **Acceptable:**
```gleam
// Status constructors - context is clear from module and return type
pub fn ok() -> Success
pub fn not_found() -> ClientError
pub fn internal_server_error() -> ServerError

// Router constructor - clearly creates a Router in router module
pub fn router() -> Router

// Other simple factories where context is obvious
pub fn empty() -> List(a)
pub fn none() -> Option(a)
```

**This exception applies when:**
- The function name and context make it unambiguous what's being created
- The module context clearly indicates what type is being constructed
- The function name directly corresponds to a type or variant name

**The deciding factor is ambiguity, not complexity.** Even complex initialization logic is fine if it's clear what's being created.

**Do NOT use this exception when:**
- Multiple different types could be created (ambiguous)
- The context doesn't clearly indicate what's being constructed
- The function name doesn't correspond to what's being created

❌ **Not acceptable - ambiguous:**
```gleam
// Ambiguous - what does this initialize?
pub fn initialize() -> Result(System, Error)  // Use create_system or init_system instead

// Ambiguous - which user? from where?
pub fn user() -> Result(User, Error)  // Use create_user, load_user, etc. instead
```

## Variable and Parameter Naming (CRITICAL)

Variables and parameters must use full, descriptive names without abbreviations, but should remain concise. Context provides meaning - don't encode everything in the variable name.

✅ **Good - Full words, concise:**
```gleam
pub fn handler(route: Route, handler_function: fn(Request) -> Response) -> Route
pub fn method(route: Route, method: Method) -> Route

fn process(request: Request, response: Response) -> Response {
  let result = {
    use user_id <- result.try(require_int(request, "id"))
    let header = get_header(request.headers, "content-type")
    use user <- result.try(authenticate(request))
    Ok(#(user_id, user))
  }
  // ...
}
```

❌ **Bad - Abbreviated:**
```gleam
pub fn handler(r: Route, h: fn(Request) -> Response) -> Route
pub fn method(rt: Route, m: Method) -> Route

fn process(request: Request, response: Response) -> Response {
  let user_id_result = require_int(request, "id")  // Use user_id (not uid)
  let header = get_header(request.headers, "content-type")  // Use header (not hdr)
  let user_result = authenticate(request)  // Use user (not u)
  // ...
}
```

❌ **Bad - Overly verbose:**
```gleam
fn process(
  incoming_http_request: Request,
  outgoing_http_response: Response
) -> Response {
  let user_identifier_from_path_params_result = require_int(request, "id")
  let user_with_verified_email_and_password = authenticate(request)
  // When you get the message, hang up!
  // ...
}
```

**Rules:**
1. **Full words required:** `request` not `req`, `response` not `resp`, `router` not `rtr`
2. **Concise but clear:** `user_id` not `uid`, but also not `user_identifier_from_database`
3. **Context provides meaning:** In a function processing users, `user` is clear; no need for `authenticated_user_object`
4. **Domain abbreviations allowed:** `html`, `http`, `url`, `id`, `json`, `xml` are universally understood
5. **Single-letter variables only for:**
   - Generic type parameters: `a`, `b`, `t`
   - Very short lambda scope (1-2 lines): `fn(x) { x + 1 }`
   - Mathematical operations: `x`, `y`, `i`, `j`

**Rationale:** Full words optimize for clarity over disk space, but excessive verbosity reduces clarity. Balance is key. **"When you get the message, hang up."**

## No Closures / Anonymous Functions (CRITICAL)

Functions cannot capture dependencies in closures. All dependencies must be explicit parameters.

- Controllers, middleware, models, operations, and helpers MUST be **named top-level functions**.
- Do **not** return anonymous functions from factory functions just to hide dependencies – instead, thread `Services` / `dependencies` explicitly.
- Anonymous functions are allowed only when absolutely required by a third-party API and cannot be avoided.

❌ **BAD - Closure hides dependency:**
```gleam
fn make_handler(db: Database) -> fn(Request) -> Response {
  fn(request) {
    // db is hidden - not obvious from signature
    query(db, request)
  }
}
```

✅ **GOOD - Dependencies explicit:**
```gleam
fn handler(request: Request, context: Context, services: Services) -> Response {
  let db = services.database  // Dependency explicit
  query(db, request)
}
```

**Why:** Closures hide dependencies, making code harder to test, understand, and maintain. Explicit parameters make all dependencies visible.

### Exception: Third-Party Module Requirements

Closures are allowed **only** when third-party modules absolutely require them and there is no alternative. This is typically necessary when interfacing with external libraries that have fixed function signatures (e.g. some Mist or Erlang/OTP callbacks).

✅ **Acceptable - Required by third-party module:**
```gleam
// Mist handler requires a function with specific signature
// No way to pass dependencies explicitly
fn create_mist_handler(services: Services) -> fn(Request) -> Response {
  fn(request) {
    // Closure required by Mist's handler interface
    handle_request(request, services)
  }
}
```

**When this exception applies:**
- Third-party library requires a specific function signature with no way to pass dependencies
- No alternative API available that supports explicit dependencies
- Document why the closure is necessary

**When this exception does NOT apply:**
- Internal Dream code (use explicit parameters)
- When you can wrap the third-party API to accept explicit dependencies
- When the third-party library provides an alternative API that supports explicit dependencies

## Error Handling (CRITICAL)

- Use `Result(success, error)` for business logic; do not rely on exceptions for control flow.
- Do NOT throw away errors with underscore patterns like `Error(_)`, `Error(_error)`, or `_`.
- Errors must be handled explicitly or at minimum bound to a named variable to show intentional handling.

❌ **BAD:**
```gleam
case result {
  Ok(val) -> val,
  Error(_) -> default  // Error thrown away
}

case result {
  Ok(val) -> val,
  Error(_error) -> default  // Error thrown away
}
```

✅ **GOOD:**
```gleam
case result {
  Ok(val) -> val,
  Error(reason) -> handle_error(reason)  // Error handled explicitly
}

case result {
  Ok(val) -> val,
  Error(timeout) -> default  // Named to show intentional handling
}
```

**Rationale:** Errors contain valuable information. Throwing them away with `_` makes debugging impossible and hides bugs. Even when intentionally discarding, name the error to show it was intentional.

## Warnings and Unused Variables

- Dream code should compile with **no warnings**.
- For each unused variable warning, do NOT blindly prefix with `_`.
- Instead, always decide one of the following and apply it consistently:
  1. **Missing behavior:** The variable represents behavior that should exist (e.g. a service or parameter you intended to use). Implement the missing logic so the variable is used.
  2. **Unused parameter:** The variable truly is not needed. Remove it from the function signature and update all call sites to match the new signature.
- Only when a parameter is required by an external interface and is intentionally unused (e.g. a callback API that passes more arguments than you need), prefix it with `_` and add a brief comment if non-obvious.

## Testing Requirements

### Coverage

- **100% test coverage** of `src/dream/` required
- All public functions must have tests

### Testing Approach

- **Black box testing only** - Test public interfaces, never private functions
- **Unit tests:** No external dependencies (no database, network, files), fast (milliseconds), deterministic
- **Integration tests:** Go in separate `test/integration/` directory

### Test Naming

Follow the pattern: `<function_name>_<condition>_<expected_result>_test()`

**Examples:**
```gleam
pub fn create_user_with_valid_data_returns_user_test()
pub fn create_user_with_empty_name_returns_error_test()
pub fn get_header_with_existing_header_returns_value_test()
pub fn get_header_with_missing_header_returns_none_test()
```

### Test Structure

Follow AAA pattern: Arrange, Act, Assert (with blank lines between sections)

**Example:**
```gleam
pub fn create_router_with_no_routes_returns_empty_router_test() {
  // Arrange
  let router = router.create_router()

  // Act
  let routes = router.get_routes()

  // Assert
  assert routes == []
}
```

## Code Formatting

Always run `gleam format` before committing:

```bash
gleam format
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
pub fn router() -> Router {
  Router(routes: [])
}
```

Include:
- Brief description of what the function does
- Example usage with imports
- Any important notes or caveats

## Control Flow & Anti-Patterns (NEVER DO)

- ❌ Closures that hide dependencies (except when required by third-party modules – see exception above).
- ❌ Anonymous functions in core Dream code paths – extract to named functions.
- ❌ Nested `case` expressions – instead, break logic into helper functions or use `result.try` / `option` helpers to sequence.
- ❌ Clever code (e.g., non-obvious tricks instead of straightforward logic).
- ❌ Global state – everything must be passed explicitly via parameters, `Context`, or `Services`.
- ❌ Abbreviated variable names.
- ❌ Module name prefixes on functions.
- ❌ Testing private functions directly.
- ❌ Throwing away errors with underscore patterns (`Error(_)`, `Error(_error)`, etc.).
- ❌ Using a non-existent `gleam/io.debug` – instead, use `string.inspect` and log via appropriate mechanisms.

## Architectural Rules (Context for Cursor)

- **No global state** – Everything is passed explicitly.
- **Result-based error handling** – No exceptions for normal control flow.
- **Context vs Services** – Context is per-request; Services are app-level dependencies.
- **Three-layer structure** – Controllers (HTTP) → Models (Data) → Utilities / Operations.

## Module and File Organization

- Aim for a **logical, discoverable module tree** – file and directory names should reflect their responsibility (e.g. `router/matcher`, `http/headers`, `services/broadcaster`).
- Avoid monolithic files that mix many concerns. When a file grows large or handles multiple concepts, split it into smaller modules grouped under a directory named for the broader concept.
- Keep naming **consistent and attractive** across modules: use the same vocabulary in file names, module names, and function names.
- Prefer splitting by responsibility (matching, parsing, formatting, persistence, etc.) rather than by arbitrary technical detail.
- When introducing new modules, update imports and re-export patterns so public APIs remain easy to discover from the main `dream` or `dream/http`/`dream/router` surfaces.

## Debugging Guidelines

When debugging (especially test failures, compilation errors, or runtime issues), **NEVER** use grep, tail, head, or any other filtering tools on the output. Always run commands with full unfiltered output (e.g., `gleam test` not `gleam test | grep something`). Filtering hides critical error messages, stack traces, and context that are essential for understanding what's wrong.

Only filter output when doing exploratory searches of a working system, never when troubleshooting failures.

## Makefile Usage

**NEVER** run a command manually that has a proper Makefile target to run it. **ALWAYS** check the Makefile for an appropriate command first.

## Publishing

**NEVER** run `gleam publish`, or any other publish command to a package repository!

## Summary Checklist

Before submitting code, verify:

- ✅ Functions follow `{verb}_{noun}` pattern
- ✅ No module name prefixes
- ✅ Full words, no abbreviations (except standard ones)
- ✅ No closures - all dependencies explicit
- ✅ Errors handled explicitly (no `Error(_)` patterns)
- ✅ 100% test coverage of `src/dream/`
- ✅ Tests use black box approach
- ✅ Test names follow `<function>_<condition>_<expected>_test()` pattern
- ✅ Code formatted with `gleam format`
- ✅ Public functions documented
- ✅ No anti-patterns violated
- ✅ Makefile targets used instead of manual commands
- ✅ Full unfiltered output when debugging

