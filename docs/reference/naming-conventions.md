# Naming Conventions

This document outlines the naming conventions for functions in the Dream web framework.

## Core Principle

**Functions must follow the `{verb}_{noun}` pattern**, where the verb describes the action and the noun describes what is being acted upon.

**Each prefix must have a unique, unambiguous purpose. No two prefixes should overlap in their use cases.**

## Module Namespace

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

## Prefix Categories

### 1. Creation & Construction

#### `create_{noun}`
**Purpose:** Creates a new instance from scratch without using a builder pattern.

**Use when:** Instantiating a type directly with constructor parameters or simple factory functions.

**Examples:**
```gleam
pub fn create_router() -> Router
pub fn create_response(status: Status) -> Response
pub fn create_cookie(name: String, value: String) -> Cookie
```

**Do NOT use when:** Building from a builder pattern (use `build_{noun}` instead).

#### `build_{noun}`
**Purpose:** Constructs a final instance from a builder pattern.

**Use when:** Converting a builder type into its final built type.

**Examples:**
```gleam
pub fn build(builder: RouteBuilder) -> Result(Route, String)
pub fn build_response(builder: ResponseBuilder) -> Response
```

**Do NOT use when:** Creating instances directly (use `create_{noun}` instead).

---

### 2. Retrieval

#### `get_{noun}`
**Purpose:** Retrieves a value from a collection by identifier/key.

**Use when:** Looking up items in lists, maps, or other collections using a name, key, or identifier.

**Examples:**
```gleam
pub fn get_header(headers: List(Header), name: String) -> Option(String)
pub fn get_cookie(cookies: List(Cookie), name: String) -> Option(Cookie)
pub fn get_query_param(query: String, name: String) -> Option(String)
pub fn get_route_by_path(router: Router, path: String) -> Option(Route)
```

**Do NOT use when:** Extracting a property from a single item (use `{noun}_name` or `{noun}_value` instead).

#### `{noun}_name`
**Purpose:** Gets the name property of a single item.

**Use when:** Extracting the name field from a single record/type instance.

**Examples:**
```gleam
pub fn cookie_name(cookie: Cookie) -> String
pub fn header_name(header: Header) -> String
pub fn route_name(route: Route) -> String
```

**Do NOT use when:** Searching for an item in a collection (use `get_{noun}` instead).

#### `{noun}_value`
**Purpose:** Gets the value property of a single item.

**Use when:** Extracting the value field from a single record/type instance.

**Examples:**
```gleam
pub fn cookie_value(cookie: Cookie) -> String
pub fn header_value(header: Header) -> String
```

**Do NOT use when:** Searching for an item in a collection (use `get_{noun}` instead).

---

### 3. Modification (Immutable)

#### `set_{noun}`
**Purpose:** Replaces or overwrites an existing value in a collection.

**Use when:** Updating a value that may already exist, replacing the old value if present.

**Examples:**
```gleam
pub fn set_header(headers: List(Header), name: String, value: String) -> List(Header)
pub fn set_cookie(cookies: List(Cookie), cookie: Cookie) -> List(Cookie)
pub fn set_config(config: Config, key: String, value: String) -> Config
```

**Do NOT use when:** Adding a new item that may not exist (use `add_{noun}` instead).

#### `add_{noun}`
**Purpose:** Adds a new item to a collection without removing existing items.

**Use when:** Appending or inserting items into collections where duplicates are allowed or desired.

**Examples:**
```gleam
pub fn add_header(headers: List(Header), name: String, value: String) -> List(Header)
pub fn route(
  router: Router,
  method: Method,
  path: String,
  controller: fn(Request) -> Response,
  middleware: List(Middleware),
) -> Router
pub fn add_middleware(builder: RouteBuilder, middleware: Middleware) -> RouteBuilder
```

**Do NOT use when:** Replacing an existing value (use `set_{noun}` instead).

#### `remove_{noun}`
**Purpose:** Removes an item from a collection.

**Use when:** Deleting items from collections by identifier/key.

**Examples:**
```gleam
pub fn remove_header(headers: List(Header), name: String) -> List(Header)
pub fn remove_cookie(cookies: List(Cookie), name: String) -> List(Cookie)
pub fn remove_route(router: Router, path: String) -> Router
```

---

### 4. Type Conversion

#### `convert_{from}_to_{to}`
**Purpose:** Converts between different types, especially when converting between external library types and internal types.

**Use when:** Transforming between types that represent the same concept but are from different modules or libraries.

**Examples:**
```gleam
pub fn convert_method(http_method: HttpMethod) -> Method
pub fn convert_request_to_response(request: Request) -> Response
pub fn convert_status_to_code(status: Status) -> Int
```

**Do NOT use when:** Parsing from strings (use `parse_{noun}` instead) or formatting to strings (use `format_{noun}` instead).

#### `parse_{noun}`
**Purpose:** Parses string or raw data into a structured type.

**Use when:** Converting unstructured text or binary data into typed structures.

**Examples:**
```gleam
pub fn parse_cookie_string(cookie_string: String) -> List(Cookie)
pub fn parse_query_string(query: String) -> Map(String, String)
pub fn parse_json(json_string: String) -> Result(Value, String)
pub fn parse_cookies_from_headers(headers: List(Header)) -> List(Cookie)
```

**Do NOT use when:** Converting between two structured types (use `convert_{from}_to_{to}` instead).

#### `format_{noun}`
**Purpose:** Formats a structured type into a string or raw data format.

**Use when:** Converting typed structures into strings or bytes for output or transmission.

**Examples:**
```gleam
pub fn format_cookie_header(cookie: Cookie) -> String
pub fn format_status_code(status: Status) -> String
pub fn format_query_string(params: Map(String, String)) -> String
```

**Do NOT use when:** Converting between two structured types (use `convert_{from}_to_{to}` instead).

#### `{from}_to_{to}`
**Purpose:** Short conversion form when the context makes the conversion clear.

**Use when:** Converting between types where the relationship is obvious and the full `convert_{from}_to_{to}` would be verbose.

**Examples:**
```gleam
pub fn method_to_string(method: Method) -> String
pub fn string_to_method(str: String) -> Option(Method)
pub fn status_to_code(status: Status) -> Int
```

**Do NOT use when:** Converting between external library types (use `convert_{from}_to_{to}` instead).

---

### 5. Boolean Checks

#### `is_{adjective}`
**Purpose:** Checks if an item has a specific property or state.

**Use when:** Evaluating a characteristic or condition of a single item.

**Examples:**
```gleam
pub fn is_method(request: Request, method: Method) -> Bool
pub fn is_secure(cookie: Cookie) -> Bool
pub fn is_authenticated(user: User) -> Bool
pub fn is_valid(response: Response) -> Bool
```

**Do NOT use when:** Checking if a collection contains an item (use `has_{noun}` instead).

#### `has_{noun}`
**Purpose:** Checks if a collection contains an item or if an item has a component.

**Use when:** Testing for presence or existence in collections or composite types.

**Examples:**
```gleam
pub fn has_content_type(request: Request, content_type: String) -> Bool
pub fn has_header(headers: List(Header), name: String) -> Bool
pub fn has_cookie(cookies: List(Cookie), name: String) -> Bool
pub fn has_middleware(route: Route) -> Bool
```

**Do NOT use when:** Checking a property of a single item (use `is_{adjective}` instead).

---

### 6. Request/Response Processing

#### `handle_{noun}`
**Purpose:** Processes HTTP requests or responses, performing business logic or transformation.

**Use when:** Implementing request handlers, middleware, or response processors that contain logic.

**Examples:**
```gleam
pub fn handle_request(request: Request) -> Response
pub fn handle_error(error: Error) -> Response
pub fn handle_authentication(request: Request) -> Result(Request, Error)
```

**Do NOT use when:** Simply routing requests (use `route_{noun}` instead).

#### `route_{noun}`
**Purpose:** Routes a request to the appropriate handler based on matching logic.

**Use when:** Finding and dispatching requests to handlers based on path, method, or other criteria.

**Examples:**
```gleam
pub fn route_request(router: Router, request: Request) -> Response
pub fn route_path(path: String, routes: List(Route)) -> Option(Route)
```

**Do NOT use when:** Processing request logic (use `handle_{noun}` instead).

#### `match_{noun}`
**Purpose:** Matches a pattern against a value, returning a boolean or result.

**Use when:** Testing if a value matches a pattern, path template, or condition.

**Examples:**
```gleam
pub fn match_path(pattern: String, path: String) -> Bool
pub fn match_method(allowed: List(Method), method: Method) -> Bool
pub fn match_route(route: Route, request: Request) -> Bool
```

**Do NOT use when:** Routing requests (use `route_{noun}` instead).

---

### 7. Error Handling

#### `handle_{noun}_error`
**Purpose:** Handles a specific error type, converting it to a result or response.

**Use when:** Implementing error recovery or transformation logic for specific error types.

**Examples:**
```gleam
pub fn handle_parse_error(error: ParseError) -> Result(Value, String)
pub fn handle_auth_error(error: AuthError) -> Response
pub fn handle_validation_error(error: ValidationError) -> Result(Validated, Error)
```

**Do NOT use when:** Recovering from errors (use `recover_from_{noun}` instead).

#### `recover_from_{noun}`
**Purpose:** Recovers from an error state, attempting to restore normal operation.

**Use when:** Implementing retry logic or fallback mechanisms.

**Examples:**
```gleam
pub fn recover_from_timeout(error: TimeoutError) -> Result(Response, Error)
pub fn recover_from_connection_error(error: ConnectionError) -> Result(Connection, Error)
```

**Do NOT use when:** Handling errors without recovery (use `handle_{noun}_error` instead).

---

### 8. Authentication & Authorization

#### `authenticate_{noun}`
**Purpose:** Verifies identity based on credentials or tokens.

**Use when:** Validating user identity, checking passwords, or verifying tokens.

**Examples:**
```gleam
pub fn authenticate_user(credentials: Credentials) -> Result(User, AuthError)
pub fn authenticate_token(token: String) -> Result(User, AuthError)
pub fn authenticate_request(request: Request) -> Result(AuthenticatedRequest, Error)
```

**Do NOT use when:** Checking permissions (use `authorize_{noun}` or `check_{noun}_permission` instead).

#### `authorize_{noun}`
**Purpose:** Checks if a user has permission to access a resource or perform an action.

**Use when:** Verifying access rights for resources or operations.

**Examples:**
```gleam
pub fn authorize_user(user: User, resource: Resource) -> Result(Unit, AuthError)
pub fn authorize_request(request: AuthenticatedRequest, action: Action) -> Result(Unit, Error)
```

**Do NOT use when:** Verifying identity (use `authenticate_{noun}` instead).

#### `check_{noun}_permission`
**Purpose:** Checks a specific permission for a user or request.

**Use when:** Testing for a particular permission flag or capability.

**Examples:**
```gleam
pub fn check_user_permission(user: User, permission: Permission) -> Bool
pub fn check_request_permission(request: Request, permission: Permission) -> Bool
```

**Do NOT use when:** Performing full authorization (use `authorize_{noun}` instead).

---

### 9. Validation

#### `validate_{noun}`
**Purpose:** Validates data and returns a Result indicating success or failure with detailed errors.

**Use when:** Performing comprehensive validation that may return multiple errors or detailed error information.

**Examples:**
```gleam
pub fn validate_request(request: Request) -> Result(ValidatedRequest, List(ValidationError))
pub fn validate_cookie(cookie: Cookie) -> Result(Cookie, ValidationError)
pub fn validate_config(config: Config) -> Result(Config, List(Error))
```

**Do NOT use when:** Simple boolean checks (use `is_{adjective}` or `has_{noun}` instead).

---

### 10. Lifecycle Management

#### `start_{noun}`
**Purpose:** Starts a service, process, or long-running operation.

**Use when:** Initiating servers, background tasks, or services.

**Examples:**
```gleam
pub fn start_server(config: ServerConfig) -> Result(Server, Error)
pub fn start_background_task(task: Task) -> Result(TaskHandle, Error)
```

**Do NOT use when:** Initializing resources (use `init_{noun}` instead).

#### `stop_{noun}`
**Purpose:** Stops a service or process immediately.

**Use when:** Halting services or processes without graceful cleanup.

**Examples:**
```gleam
pub fn stop_server(server: Server) -> Result(Unit, Error)
pub fn stop_task(handle: TaskHandle) -> Result(Unit, Error)
```

**Do NOT use when:** Gracefully shutting down (use `shutdown_{noun}` instead).

#### `init_{noun}`
**Purpose:** Initializes a resource or component with configuration.

**Use when:** Setting up resources, loading configuration, or preparing for use.

**Examples:**
```gleam
pub fn init_database(config: DatabaseConfig) -> Result(Database, Error)
pub fn init_logger(config: LoggerConfig) -> Result(Logger, Error)
pub fn init_services(config: Config) -> Result(Services, Error)
```

**Do NOT use when:** Starting services (use `start_{noun}` instead).

#### `shutdown_{noun}`
**Purpose:** Gracefully shuts down a service, performing cleanup operations.

**Use when:** Stopping services with proper cleanup, saving state, or closing connections.

**Examples:**
```gleam
pub fn shutdown_server(server: Server) -> Result(Unit, Error)
pub fn shutdown_database(database: Database) -> Result(Unit, Error)
```

**Do NOT use when:** Immediate stopping (use `stop_{noun}` instead).

---

### 11. Serialization

#### `serialize_{noun}`
**Purpose:** Converts a structured type into a serialized format (bytes or string).

**Use when:** Encoding data for storage or transmission.

**Examples:**
```gleam
pub fn serialize_response(response: Response) -> Bytes
pub fn serialize_config(config: Config) -> String
pub fn serialize_user(user: User) -> Bytes
```

**Do NOT use when:** Formatting for display (use `format_{noun}` instead).

#### `deserialize_{noun}`
**Purpose:** Converts serialized data (bytes or string) into a structured type.

**Use when:** Decoding data from storage or transmission.

**Examples:**
```gleam
pub fn deserialize_response(bytes: Bytes) -> Result(Response, Error)
pub fn deserialize_config(json: String) -> Result(Config, Error)
pub fn deserialize_user(bytes: Bytes) -> Result(User, Error)
```

**Do NOT use when:** Parsing from strings with complex structure (use `parse_{noun}` instead).

---

### 12. State Management

#### `load_{noun}`
**Purpose:** Loads data from persistent storage by identifier.

**Use when:** Retrieving data from databases, files, or other persistent storage.

**Examples:**
```gleam
pub fn load_user(id: UserId) -> Result(User, Error)
pub fn load_config(path: String) -> Result(Config, Error)
pub fn load_settings(key: String) -> Result(Settings, Error)
```

**Do NOT use when:** Retrieving from memory/cache (use `get_{noun}` instead).

#### `save_{noun}`
**Purpose:** Saves data to persistent storage.

**Use when:** Writing data to databases, files, or other persistent storage.

**Examples:**
```gleam
pub fn save_user(user: User) -> Result(UserId, Error)
pub fn save_config(config: Config, path: String) -> Result(Unit, Error)
```

**Do NOT use when:** Storing in memory (use `store_{noun}` instead).

#### `store_{noun}`
**Purpose:** Stores data in memory or cache.

**Use when:** Keeping data in memory, cache, or temporary storage.

**Examples:**
```gleam
pub fn store_session(key: String, session: Session) -> Result(Unit, Error)
pub fn store_cache(key: String, value: Value) -> Result(Unit, Error)
```

**Do NOT use when:** Persisting to storage (use `save_{noun}` instead).

#### `restore_{noun}`
**Purpose:** Restores data from a backup or checkpoint.

**Use when:** Recovering from backups, checkpoints, or saved states.

**Examples:**
```gleam
pub fn restore_database(backup_id: String) -> Result(Database, Error)
pub fn restore_session(session_id: String) -> Result(Session, Error)
```

**Do NOT use when:** Loading current data (use `load_{noun}` instead).

---

### 13. Response Builders

#### `{type}_response`
**Purpose:** Creates a response of a specific content type.

**Use when:** Constructing HTTP responses with specific content types or formats.

**Examples:**
```gleam
pub fn text_response(status: Status, body: String) -> Response
pub fn json_response(status: Status, body: String) -> Response
pub fn html_response(status: Status, body: String) -> Response
pub fn redirect_response(status: Status, location: String) -> Response
pub fn empty_response(status: Status) -> Response
```

**Do NOT use when:** Creating generic responses (use `create_response` instead).

---

### 14. Configuration (Builder Pattern Exception)

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

---

### 15. Factory Function Exception

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

✅ **Acceptable - unambiguous:**
```gleam
// In router module - clearly creates a Router
pub fn router() -> Router {
  Router(routes: [], middleware: [], config: default_config())
}

// In database module - clearly creates a Database
pub fn database(url: String) -> Result(Database, Error) {
  // ... complex initialization logic
  Ok(Database(...))
}
```

**Examples that follow the exception:**
- Status constructors: `ok()`, `created()`, `not_found()`, `bad_request()`
- Type constructors in their own modules: `router()`, `database()`, `server()`
- Standard library patterns: `none()`, `empty()`, `default()`, `zero()`

---

## Variable and Parameter Naming

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
  let user_id_result = require_int(request, "id")  // Use user_id (not uid), and use require_int
  let header = get_header(request.headers, "content-type")  // Use header (not hdr), use full name
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

---

## Summary

1. **Always use `{verb}_{noun}` pattern** for function names
2. **Never prefix with module name** - the module provides the namespace
3. **Each prefix has a distinct purpose** - no overlaps allowed
4. **Use descriptive verbs**: `create`, `get`, `set`, `add`, `remove`, `convert`, `parse`, `format`, `handle`, `route`, `validate`, `start`, `stop`, etc.
5. **Use descriptive nouns**: be specific about what is being acted upon
6. **Exceptions allowed**: 
   - Builder pattern: Simple verbs in fluent APIs when context is clear
   - Factory functions: `create_{noun}` can be shortened to `{noun}` when context makes it unambiguous what's being created
7. **Consistency**: Follow these patterns consistently across the codebase
