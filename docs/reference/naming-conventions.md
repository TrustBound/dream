# Naming Conventions

This document outlines the naming conventions for functions in the Dream web framework.

## Core Principle

**Functions must follow the `{verb}_{noun}` pattern**, where the verb describes the action and the noun describes what is being acted upon.

**Each prefix must have a unique, unambiguous purpose. No two prefixes should overlap in their use cases.**

## Module Namespace

The module name provides the namespace, so functions must **not** be prefixed with the module name.

### ✅ Good: the module name is the namespace <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/naming_module_namespace.gleam#L11-L18"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn show_user(id: Int) -> Result(User, Nil) {
  user.find(id)
}

pub fn app_router() {
  router.router()
  |> router.route(method: Get, path: "/", controller: index, middleware: [])
}
```

### ❌ Bad: the function repeats the module name <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/naming_module_namespace.gleam#L20-L22"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn show_user_with_module_prefix(id: Int) -> Result(User, Nil) {
  user.user_find(id)
}
```

`user.user_find(id)` says "user" two times. The module name already says it, so the name `find` is enough.

## Imports

Gleam code uses unqualified imports by default. Import the types, constructors and functions you use, and call them bare.

### ✅ Good: import the names and call them bare <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/naming_imports.gleam#L5-L17"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
//// two imports offer the same name, qualify it on both sides.

import dream/http/error.{from_shared, message, to_status_code}
import dream/http/response.{type Response, text_response}
import dream_errors

pub fn not_found_response() -> Response {
  error_response(error.NotFound("User not found"))
}

pub fn error_response(failure: error.Error) -> Response {
  text_response(to_status_code(failure), message(failure))
}
```

The import line names each thing the code uses. The calls stay short. `dream_errors` is for the clash example below. It also offers `NotFound` and `Error`, so those keep their module on both sides.

### ❌ Bad: needlessly qualified <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/naming_imports.gleam#L19-L21"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn error_response_qualified(failure: error.Error) -> response.Response {
  response.text_response(error.to_status_code(failure), error.message(failure))
}
```

`error.Error` keeps its module because `dream_errors` also offers `Error`. No other name here clashes, so the `response.` prefixes and `error.to_status_code` and `error.message` only add noise.

### ✅ Good: qualified because the name clashes <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/naming_imports.gleam#L23-L33"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn shared_error_response(shared: dream_errors.Error(Nil)) -> Response {
  case shared {
    dream_errors.NotFound(..) -> not_found_with_message("User not found")
    other -> error_response(from_shared(other))
  }
}

pub fn not_found_with_message(message: String) -> Response {
  let failure = error.NotFound(message)
  text_response(to_status_code(failure), error.message(failure))
}
```

Qualify a name only when the bare name would clash with one of these:

- **Another import.** When two imports offer the same name, qualify it on both sides. Dream and `dream_errors` both offer `NotFound` and `Error`, so the code writes `error.NotFound` and `dream_errors.NotFound`, and `error.Error` and `dream_errors.Error`. A bare name would hide which one it means.
- **A local definition or a parameter.** The parameter `message` hides the imported `message` function, so the call is `error.message`.
- **A module name in scope.** If the code imports `gleam/int` as a module, write `client.int`. A bare `int` would read as the module.

## Prefix Categories

### 1. Creation & Construction

#### `create_{noun}`
**Purpose:** Creates a new instance from scratch without using a builder pattern.

**Use when:** Instantiating a type directly with constructor parameters or simple factory functions.

##### Creating a response, a cookie and a header <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/naming_creation.gleam#L18-L28"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn create_response(status: Int) -> Response {
  response.empty_response(status)
}

pub fn create_cookie(name: String, value: String) -> Cookie {
  cookie.simple_cookie(name, value)
}

pub fn create_header(name: String, value: String) -> Header {
  Header(name:, value:)
}
```

**Do NOT use when:** Building from a builder pattern (use `build_{noun}` instead).

#### `build_{noun}`
**Purpose:** Constructs a final instance from a builder pattern.

**Use when:** Converting a builder type into its final built type.

##### Building a response and a cookie from builders <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/naming_creation.gleam#L30-L38"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn build_response(builder: ResponseBuilder) -> Response {
  let text = response.text_response(builder.status, builder.body)
  Response(..text, headers: builder.headers)
}

pub fn build_cookie(builder: CookieBuilder) -> Cookie {
  let simple = cookie.simple_cookie(builder.name, builder.value)
  Cookie(..simple, secure: builder.secure)
}
```

**Do NOT use when:** Creating instances directly (use `create_{noun}` instead).

---

### 2. Retrieval

#### `get_{noun}`
**Purpose:** Retrieves a value from a collection by identifier/key.

**Use when:** Looking up items in lists, maps, or other collections using a name, key, or identifier.

##### Getting a header, a cookie and a query parameter <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/naming_retrieval.gleam#L18-L20"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
  let content_type = http.get_header(request.headers, "Content-Type")
  let session = http.get_cookie(request.cookies, "session")
  let page = http.get_query_param(request.query, "page")
```

**Do NOT use when:** Extracting a property from a single item (use `{noun}_name` or `{noun}_value` instead).

#### `{noun}_name`
**Purpose:** Gets the name property of a single item.

**Use when:** Extracting the name field from a single record/type instance.

##### Reading the name of a cookie and a header <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/naming_retrieval.gleam#L25-L26"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
  let cookie_name = http.cookie_name(cookie)
  let header_name = http.header_name(header)
```

**Do NOT use when:** Searching for an item in a collection (use `get_{noun}` instead).

#### `{noun}_value`
**Purpose:** Gets the value property of a single item.

**Use when:** Extracting the value field from a single record/type instance.

##### Reading the value of a cookie and a header <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/naming_retrieval.gleam#L31-L32"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
  let cookie_value = http.cookie_value(cookie)
  let header_value = http.header_value(header)
```

**Do NOT use when:** Searching for an item in a collection (use `get_{noun}` instead).

---

### 3. Modification (Immutable)

#### `set_{noun}`
**Purpose:** Replaces or overwrites an existing value in a collection.

**Use when:** Updating a value that may already exist, replacing the old value if present.

##### Setting a header and a cookie <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/naming_modification.gleam#L13-L15"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
  let headers = header.set_header(request.headers, "Cache-Control", "no-store")
  let cookies =
    cookie.set_cookie(request.cookies, cookie.simple_cookie("theme", "dark"))
```

**Do NOT use when:** Adding a new item that may not exist (use `add_{noun}` instead).

#### `add_{noun}`
**Purpose:** Adds a new item to a collection without removing existing items.

**Use when:** Appending or inserting items into collections where duplicates are allowed or desired.

##### Adding a header and a route <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/naming_modification.gleam#L20-L24"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
  let headers =
    header.add_header(request.headers, "Link", "</app.css>; rel=preload")
  let app_router =
    router.router()
    |> router.route(method: Get, path: "/", controller: index, middleware: [])
```

**Do NOT use when:** Replacing an existing value (use `set_{noun}` instead).

#### `remove_{noun}`
**Purpose:** Removes an item from a collection.

**Use when:** Deleting items from collections by identifier/key.

##### Removing a header and a cookie <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/naming_modification.gleam#L29-L30"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
  let headers = header.remove_header(request.headers, "X-Tracking-Id")
  let cookies = cookie.remove_cookie(request.cookies, "tracking")
```

---

### 4. Type Conversion

#### `convert_{from}_to_{to}`
**Purpose:** Converts between different types, especially when converting between external library types and internal types.

**Use when:** Transforming between types that represent the same concept but are from different modules or libraries.

##### Converting a method and a cookie <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/naming_conversion.gleam#L25-L35"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn convert_http_method_to_method(
  http_method: gleam_http.Method,
) -> Option(Method) {
  http_method
  |> gleam_http.method_to_string
  |> request.parse_method
}

pub fn convert_cookie_to_header(cookie: Cookie) -> Header {
  Header(name: "Set-Cookie", value: format_cookie_header(cookie))
}
```

**Do NOT use when:** Parsing from strings (use `parse_{noun}` instead) or formatting to strings (use `format_{noun}` instead).

#### `parse_{noun}`
**Purpose:** Parses string or raw data into a structured type.

**Use when:** Converting unstructured text or binary data into typed structures.

##### Parsing cookies and a method <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/naming_conversion.gleam#L38-L40"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
  let cookies = dream.parse_cookie_string("theme=dark; session=abc123")
  let method = request.parse_method("POST")
  let header_cookies = dream.parse_cookies_from_headers(headers)
```

**Do NOT use when:** Converting between two structured types (use `convert_{from}_to_{to}` instead).

#### `format_{noun}`
**Purpose:** Formats a structured type into a string or raw data format.

**Use when:** Converting typed structures into strings or bytes for output or transmission.

##### Formatting a cookie header and a query string <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/naming_conversion.gleam#L44-L57"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn format_cookie_header(cookie: Cookie) -> String {
  cookie.name <> "=" <> cookie.value
}

pub fn format_query_string(parameters: List(#(String, String))) -> String {
  parameters
  |> list.map(format_query_parameter)
  |> string.join("&")
}

fn format_query_parameter(parameter: #(String, String)) -> String {
  let #(name, value) = parameter
  uri.percent_encode(name) <> "=" <> uri.percent_encode(value)
}
```

**Do NOT use when:** Converting between two structured types (use `convert_{from}_to_{to}` instead).

#### `{from}_to_{to}`
**Purpose:** Short conversion form when the context makes the conversion clear.

**Use when:** Converting between types where the relationship is obvious and the full `convert_{from}_to_{to}` would be verbose.

##### Converting a header to a pair and back <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/naming_conversion.gleam#L59-L66"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn header_to_pair(header: Header) -> #(String, String) {
  #(header.name, header.value)
}

pub fn pair_to_header(pair: #(String, String)) -> Header {
  let #(name, value) = pair
  Header(name:, value:)
}
```

**Do NOT use when:** Converting between external library types (use `convert_{from}_to_{to}` instead).

---

### 5. Boolean Checks

#### `is_{adjective}`
**Purpose:** Checks if an item has a specific property or state.

**Use when:** Evaluating a characteristic or condition of a single item.

##### Checking a request, a cookie and a response <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/naming_checks.gleam#L10-L20"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn is_post(request: Request) -> Bool {
  http.is_method(request, Post)
}

pub fn is_secure(cookie: Cookie) -> Bool {
  cookie.secure
}

pub fn is_json(response: Response) -> Bool {
  response.content_type == Some("application/json; charset=utf-8")
}
```

**Do NOT use when:** Checking if a collection contains an item (use `has_{noun}` instead).

#### `has_{noun}`
**Purpose:** Checks if a collection contains an item or if an item has a component.

**Use when:** Testing for presence or existence in collections or composite types.

##### Checking for a body, a header and a cookie <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/naming_checks.gleam#L22-L32"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn has_json_body(request: Request) -> Bool {
  http.has_content_type(request, "application/json")
}

pub fn has_header(headers: List(Header), name: String) -> Bool {
  option.is_some(http.get_header(headers, name))
}

pub fn has_cookie(cookies: List(Cookie), name: String) -> Bool {
  option.is_some(http.get_cookie(cookies, name))
}
```

**Do NOT use when:** Checking a property of a single item (use `is_{adjective}` instead).

---

### 6. Request/Response Processing

#### `handle_{noun}`
**Purpose:** Processes HTTP requests or responses, performing business logic or transformation.

**Use when:** Implementing request handlers, middleware, or response processors that contain logic.

##### Handling a request, an error and authentication <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/naming_processing.gleam#L16-L32"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn handle_request(request: Request) -> Response {
  case handle_authentication(request) {
    Ok(_request) -> http.text_response(http.ok, "Welcome")
    Error(error) -> handle_error(error)
  }
}

pub fn handle_error(error: Error) -> Response {
  http.text_response(to_status_code(error), message(error))
}

pub fn handle_authentication(request: Request) -> Result(Request, Error) {
  case http.get_header(request.headers, "Authorization") {
    Some(_token) -> Ok(request)
    None -> Error(Unauthorized("Missing Authorization header"))
  }
}
```

**Do NOT use when:** Simply routing requests (use `route_{noun}` instead).

#### `route_{noun}`
**Purpose:** Routes a request to the appropriate handler based on matching logic.

**Use when:** Finding and dispatching requests to handlers based on path, method, or other criteria.

##### Routing a request to its controller <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/naming_processing.gleam#L34-L39"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn respond(request: Request) -> Response {
  let app_router =
    router.router()
    |> router.route(method: Get, path: "/", controller: home, middleware: [])
  dream.route_request(app_router, request, Nil, Nil)
}
```

**Do NOT use when:** Processing request logic (use `handle_{noun}` instead).

#### `match_{noun}`
**Purpose:** Matches a pattern against a value, returning a boolean or result.

**Use when:** Testing if a value matches a pattern, path template, or condition.

##### Matching a method and a path <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/naming_processing.gleam#L41-L55"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn match_method(allowed: List(Method), method: Method) -> Bool {
  list.contains(allowed, method)
}

pub fn match_path(pattern: String, path: String) -> Bool {
  let pattern_segments = string.split(pattern, "/")
  let path_segments = string.split(path, "/")
  list.length(pattern_segments) == list.length(path_segments)
  && list.all(list.zip(pattern_segments, path_segments), match_segment)
}

fn match_segment(segments: #(String, String)) -> Bool {
  let #(pattern_segment, path_segment) = segments
  string.starts_with(pattern_segment, ":") || pattern_segment == path_segment
}
```

**Do NOT use when:** Routing requests (use `route_{noun}` instead).

---

### 7. Error Handling

#### `handle_{noun}_error`
**Purpose:** Handles a specific error type, converting it to a result or response.

**Use when:** Implementing error recovery or transformation logic for specific error types.

##### Handling a parse error and an authentication error <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/naming_errors.gleam#L19-L28"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn handle_parse_error(_error: json.DecodeError) -> Response {
  http.text_response(http.bad_request, "The body is not valid JSON")
}

pub fn handle_auth_error(error: AuthError) -> Response {
  case error {
    MissingToken -> http.text_response(http.unauthorized, "Sign in first")
    ExpiredToken -> http.text_response(http.unauthorized, "Sign in again")
  }
}
```

**Do NOT use when:** Recovering from errors (use `recover_from_{noun}` instead).

#### `recover_from_{noun}`
**Purpose:** Recovers from an error state, attempting to restore normal operation.

**Use when:** Implementing retry logic or fallback mechanisms.

##### Recovering from a timeout and a connection error <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/naming_errors.gleam#L30-L48"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn recover_from_timeout(
  result: Result(String, FetchError),
  retry: fn() -> Result(String, FetchError),
) -> Result(String, FetchError) {
  case result {
    Error(Timeout) -> retry()
    _ -> result
  }
}

pub fn recover_from_connection_error(
  result: Result(String, FetchError),
  cached: String,
) -> Result(String, FetchError) {
  case result {
    Error(ConnectionRefused) -> Ok(cached)
    _ -> result
  }
}
```

**Do NOT use when:** Handling errors without recovery (use `handle_{noun}_error` instead).

---

### 8. Authentication & Authorization

#### `authenticate_{noun}`
**Purpose:** Verifies identity based on credentials or tokens.

**Use when:** Validating user identity, checking passwords, or verifying tokens.

##### Authenticating a user, a token and a request <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/naming_auth.gleam#L42-L61"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn authenticate_user(credentials: Credentials) -> Result(User, AuthError) {
  case credentials {
    Credentials(username: "ada", password: "correct-horse") -> Ok(ada)
    _ -> Error(InvalidCredentials)
  }
}

pub fn authenticate_token(token: String) -> Result(User, AuthError) {
  case token {
    "token-ada" -> Ok(ada)
    _ -> Error(InvalidToken)
  }
}

pub fn authenticate_request(request: Request) -> Result(User, AuthError) {
  case http.get_header(request.headers, "Authorization") {
    Some("Bearer " <> token) -> authenticate_token(token)
    _ -> Error(InvalidToken)
  }
}
```

**Do NOT use when:** Checking permissions (use `authorize_{noun}` or `check_{noun}_permission` instead).

#### `authorize_{noun}`
**Purpose:** Checks if a user has permission to access a resource or perform an action.

**Use when:** Verifying access rights for resources or operations.

##### Authorizing a user and a request <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/naming_auth.gleam#L63-L76"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn authorize_user(user: User, article: Article) -> Result(Nil, AuthError) {
  case user.id == article.author_id || user.role == Editor {
    True -> Ok(Nil)
    False -> Error(Forbidden)
  }
}

pub fn authorize_request(
  request: Request,
  article: Article,
) -> Result(Nil, AuthError) {
  use user <- result.try(authenticate_request(request))
  authorize_user(user, article)
}
```

**Do NOT use when:** Verifying identity (use `authenticate_{noun}` instead).

#### `check_{noun}_permission`
**Purpose:** Checks a specific permission for a user or request.

**Use when:** Testing for a particular permission flag or capability.

##### Checking a user permission and a request permission <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/naming_auth.gleam#L78-L90"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn check_user_permission(user: User, permission: Permission) -> Bool {
  list.contains(role_permissions(user.role), permission)
}

pub fn check_request_permission(
  request: Request,
  permission: Permission,
) -> Bool {
  case authenticate_request(request) {
    Ok(user) -> check_user_permission(user, permission)
    Error(_error) -> False
  }
}
```

**Do NOT use when:** Performing full authorization (use `authorize_{noun}` instead).

---

### 9. Validation

#### `validate_{noun}`
**Purpose:** Validates data and returns a Result indicating success or failure with detailed errors.

**Use when:** Performing comprehensive validation that may return multiple errors or detailed error information.

##### Validating a signup and a cookie <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/naming_validation.gleam#L19-L34"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn validate_signup(signup: Signup) -> Result(Signup, List(SignupError)) {
  let errors =
    [email_error(signup.email), password_error(signup.password)]
    |> option.values
  case errors {
    [] -> Ok(signup)
    _ -> Error(errors)
  }
}

pub fn validate_cookie(cookie: Cookie) -> Result(Cookie, String) {
  case cookie.secure {
    True -> Ok(cookie)
    False -> Error("The " <> cookie.name <> " cookie must be secure")
  }
}
```

**Do NOT use when:** Simple boolean checks (use `is_{adjective}` or `has_{noun}` instead).

---

### 10. Lifecycle Management

#### `start_{noun}`
**Purpose:** Starts a service, process, or long-running operation.

**Use when:** Initiating servers, background tasks, or services.

##### Starting a server <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/naming_lifecycle.gleam#L24-L28"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn start_server(port: Int) {
  server.new()
  |> server.router(app_router())
  |> server.listen_with_handle(port)
}
```

**Do NOT use when:** Initializing resources (use `init_{noun}` instead).

#### `stop_{noun}`
**Purpose:** Stops a service or process immediately.

**Use when:** Halting services or processes without graceful cleanup.

##### Stopping a server <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/naming_lifecycle.gleam#L30-L32"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn stop_server(handle: server.ServerHandle) -> Nil {
  server.stop(handle)
}
```

**Do NOT use when:** Gracefully shutting down (use `shutdown_{noun}` instead).

#### `init_{noun}`
**Purpose:** Initializes a resource or component with configuration.

**Use when:** Setting up resources, loading configuration, or preparing for use.

##### Initializing a database and services <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/naming_lifecycle.gleam#L34-L44"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn init_database(config: DatabaseConfig) -> Result(Database, String) {
  case config.pool_size > 0 {
    True -> Ok(Database(url: config.url, connections: config.pool_size))
    False -> Error("pool_size must be greater than 0")
  }
}

pub fn init_services(config: DatabaseConfig) -> Result(Services, String) {
  use database <- result.try(init_database(config))
  Ok(Services(database:))
}
```

**Do NOT use when:** Starting services (use `start_{noun}` instead).

#### `shutdown_{noun}`
**Purpose:** Gracefully shuts down a service, performing cleanup operations.

**Use when:** Stopping services with proper cleanup, saving state, or closing connections.

##### Shutting down a database and services <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/naming_lifecycle.gleam#L46-L52"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn shutdown_database(database: Database) -> Database {
  Database(..database, connections: 0)
}

pub fn shutdown_services(services: Services) -> Services {
  Services(database: shutdown_database(services.database))
}
```

**Do NOT use when:** Immediate stopping (use `stop_{noun}` instead).

---

### 11. Serialization

#### `serialize_{noun}`
**Purpose:** Converts a structured type into a serialized format (bytes or string).

**Use when:** Encoding data for storage or transmission.

##### Serializing a user and a session <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/naming_serialization.gleam#L21-L28"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn serialize_user(user: User) -> String {
  json.object([#("id", json.int(user.id)), #("name", json.string(user.name))])
  |> json.to_string
}

pub fn serialize_session(session: Session) -> BitArray {
  bit_array.from_string(session.id <> ":" <> int.to_string(session.user_id))
}
```

**Do NOT use when:** Formatting for display (use `format_{noun}` instead).

#### `deserialize_{noun}`
**Purpose:** Converts serialized data (bytes or string) into a structured type.

**Use when:** Decoding data from storage or transmission.

##### Deserializing a user and a session <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/naming_serialization.gleam#L30-L39"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn deserialize_user(text: String) -> Result(User, json.DecodeError) {
  json.parse(text, user_decoder())
}

pub fn deserialize_session(bytes: BitArray) -> Result(Session, Nil) {
  use text <- result.try(bit_array.to_string(bytes))
  use #(id, user_id_text) <- result.try(string.split_once(text, ":"))
  use user_id <- result.try(int.parse(user_id_text))
  Ok(Session(id:, user_id:))
}
```

**Do NOT use when:** Parsing from strings with complex structure (use `parse_{noun}` instead).

---

### 12. State Management

#### `load_{noun}`
**Purpose:** Loads data from persistent storage by identifier.

**Use when:** Retrieving data from databases, files, or other persistent storage.

##### Loading a user and a config file <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/naming_state.gleam#L24-L30"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn load_user(database: Database, id: Int) -> Result(User, Nil) {
  dict.get(database.users, id)
}

pub fn load_config(path: String) -> Result(String, simplifile.FileError) {
  simplifile.read(path)
}
```

**Do NOT use when:** Retrieving from memory/cache (use `get_{noun}` instead).

#### `save_{noun}`
**Purpose:** Saves data to persistent storage.

**Use when:** Writing data to databases, files, or other persistent storage.

##### Saving a user and a config file <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/naming_state.gleam#L32-L41"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn save_user(database: Database, user: User) -> Database {
  Database(users: dict.insert(database.users, user.id, user))
}

pub fn save_config(
  config: String,
  path: String,
) -> Result(Nil, simplifile.FileError) {
  simplifile.write(to: path, contents: config)
}
```

**Do NOT use when:** Storing in memory (use `store_{noun}` instead).

#### `store_{noun}`
**Purpose:** Stores data in memory or cache.

**Use when:** Keeping data in memory, cache, or temporary storage.

##### Storing a session in memory <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/naming_state.gleam#L43-L48"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn store_session(
  sessions: Dict(String, Session),
  session: Session,
) -> Dict(String, Session) {
  dict.insert(sessions, session.id, session)
}
```

**Do NOT use when:** Persisting to storage (use `save_{noun}` instead).

#### `restore_{noun}`
**Purpose:** Restores data from a backup or checkpoint.

**Use when:** Recovering from backups, checkpoints, or saved states.

##### Restoring sessions and a config file <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/naming_state.gleam#L50-L60"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn restore_sessions(snapshot: List(Session)) -> Dict(String, Session) {
  list.fold(snapshot, dict.new(), store_session)
}

pub fn restore_config(
  backup_path: String,
  path: String,
) -> Result(Nil, simplifile.FileError) {
  use backup <- result.try(simplifile.read(backup_path))
  simplifile.write(to: path, contents: backup)
}
```

**Do NOT use when:** Loading current data (use `load_{noun}` instead).

---

### 13. Response Builders

#### `{type}_response`
**Purpose:** Creates a response of a specific content type.

**Use when:** Constructing HTTP responses with specific content types or formats.

##### Making responses of each content type <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/naming_responses.gleam#L8-L12"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
  let text = http.text_response(http.ok, "Hello")
  let json = http.json_response(http.ok, "{\"message\":\"Hello\"}")
  let html = http.html_response(http.ok, "<h1>Hello</h1>")
  let redirect = http.redirect_response(http.see_other, "/login")
  let empty = http.empty_response(http.no_content)
```

**Do NOT use when:** The response has no single content type. Then build the `Response` record directly. The helpers in `dream/http/response` are `text_response`, `json_response`, `html_response`, `binary_response`, `redirect_response`, `empty_response`, `stream_response` and `sse_response`.

---

### 14. Configuration (Builder Pattern Exception)

For fluent builder APIs, simple action verbs without nouns are acceptable when the builder type provides context:

#### ✅ Acceptable: the server builder <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/naming_builder.gleam#L12-L15"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
  server.new()
  |> server.router(app_router())
  |> server.bind("localhost")
  |> server.listen_with_handle(port)
```

This exception applies only to:
- Builder pattern configuration methods
- When the builder type provides clear context
- When full names would be overly verbose

**Do NOT use this exception for:** General-purpose functions outside of builder patterns.

---

### 15. Factory Function Exception

For factory functions that create instances where context makes it unambiguous, `create_{noun}` can be shortened to just `{noun}`:

#### ✅ Acceptable: the router constructor <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/naming_factory.gleam#L24-L25"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
  // Router constructor: the router module creates a Router
  let app_router = router.router()
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

#### ❌ Not acceptable: ambiguous factories <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/naming_factory.gleam#L30-L40"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
// Ambiguous: what does this initialize?
// Use create_services or init_services instead.
pub fn initialize() -> Result(Services, String) {
  Ok(Services(users: []))
}

// Ambiguous: which user? From where?
// Use create_user or load_user instead.
pub fn user() -> Result(User, String) {
  Ok(User(id: 1, name: "Ada"))
}
```

#### ✅ Acceptable: an unambiguous factory <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/naming_factory.gleam#L42-L48"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
// Clearly creates a Database
pub fn database(url: String) -> Result(Database, String) {
  case string.starts_with(url, "postgres://") {
    True -> Ok(Database(url:))
    False -> Error("The database URL must start with postgres://")
  }
}
```

**Examples that follow the exception:**
- Type constructors in their own modules: `router.router()`, `database()`
- Standard library patterns: `dict.new()`, `set.new()`, `list.new()`, and the `option.None` constructor

---

## Variable and Parameter Naming

Variables and parameters must use full, descriptive names without abbreviations, but should remain concise. Context provides meaning - don't encode everything in the variable name.

### ✅ Good: full words, concise <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/naming_variables_good.gleam#L7-L13"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn show_user(request: Request, _context, services: Services) -> Response {
  let user_result = {
    use user_id <- result.try(http.require_int(request, "id"))
    find_user(services.users, user_id)
  }
  respond_with_user(user_result)
}
```

### ❌ Bad: abbreviated <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/naming_variables_abbreviated.gleam#L7-L13"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn show_user(req: Request, _ctx, svcs: Services) -> Response {
  let res = {
    use uid <- result.try(http.require_int(req, "id"))
    find_user(svcs.users, uid)
  }
  respond_with_user(res)
}
```

`req`, `ctx`, `svcs`, `res` and `uid` save a few letters, but the reader must guess each word.

### ❌ Bad: overly verbose <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/naming_variables_verbose.gleam#L7-L24"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn show_user(
  incoming_http_request: Request,
  _request_context_value,
  application_services_record: Services,
) -> Response {
  let user_lookup_result_from_services = {
    use user_identifier_from_path_parameters <- result.try(http.require_int(
      incoming_http_request,
      "id",
    ))
    find_user(
      application_services_record.users,
      user_identifier_from_path_parameters,
    )
  }
  // When you get the message, hang up!
  respond_with_user(user_lookup_result_from_services)
}
```

Each name repeats what the types and the function already say. The extra words make the code harder to read.

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
3. **Import names unqualified** - qualify a name only when the bare name would clash. When two imports offer the same name, qualify it on both sides
4. **Each prefix has a distinct purpose** - no overlaps allowed
5. **Use descriptive verbs**: `create`, `get`, `set`, `add`, `remove`, `convert`, `parse`, `format`, `handle`, `route`, `validate`, `start`, `stop`, etc.
6. **Use descriptive nouns**: be specific about what is being acted upon
7. **Exceptions allowed**: 
   - Builder pattern: Simple verbs in fluent APIs when context is clear
   - Factory functions: `create_{noun}` can be shortened to `{noun}` when context makes it unambiguous what's being created
8. **Consistency**: Follow these patterns consistently across the codebase
