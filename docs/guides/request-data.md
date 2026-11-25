[README](https://hexdocs.pm/dream/3.0.0/) > [Guides](https://hexdocs.pm/dream/3.0.0/guides/index.html) > Read request data safely

# Read request data safely

Every value in a request comes from outside your program: the id in the path, the search term in the query string, the JSON a client posts, the fields of a form. Any of them can be missing or the wrong type, and your controller has to say so with a clear `400` instead of crashing or saving junk. This guide reads each kind of request data with Dream's helpers and shows the real answer for good input and for bad input. The code is the `request_data_controller` of `examples/simple`, and every output is what that server answers.

## Table of Contents

- [What you'll build](#what-youll-build)
- [Before you start](#before-you-start)
- [Which helper to use](#which-helper-to-use)
- [Step 1: Read a path parameter](#step-1-read-a-path-parameter)
- [Step 2: Read the query string](#step-2-read-the-query-string)
- [Step 3: Validate a JSON body and report every error](#step-3-validate-a-json-body-and-report-every-error)
- [Step 4: Read a form](#step-4-read-a-form)
- [Step 5: Check business rules after decoding](#step-5-check-business-rules-after-decoding)
- [Turn errors into answers](#turn-errors-into-answers)
- [Test your code](#test-your-code)
- [Common pitfalls](#common-pitfalls)
- [Where to go next](#where-to-go-next)

## What you'll build

- `GET /users/:id`, which answers `400` when the id isn't a whole number.
- `GET /search?q=...`, which answers `400` when `q` is missing.
- `POST /signups`, which decodes a JSON body and lists every field that's wrong in one answer.
- `POST /contact`, which reads a form with a required and an optional field.
- A test of a JSON controller with valid input, wrong fields and broken JSON.

## Before you start

Read [Route requests and add middleware](https://hexdocs.pm/dream/3.0.0/guides/routing.html) for routes and path parameters. Add Dream, and `gleam_json` for building JSON answers:

```sh
gleam add dream gleam_json
```

The example runs from the Dream repository with `make run` in `examples/simple`, on port 3000. Its routes:

### The request data routes <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/src/router.gleam#L23-L46"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
  )
  |> route(
    method: Get,
    path: "/users/:id",
    controller: request_data_controller.show_user,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/search",
    controller: request_data_controller.search,
    middleware: [],
  )
  |> route(
    method: Post,
    path: "/signups",
    controller: request_data_controller.create_signup,
    middleware: [],
  )
  |> route(
    method: Post,
    path: "/contact",
    controller: request_data_controller.create_contact,
    middleware: [],
```

## Which helper to use

| The data | Helper | What you get |
|:---|:---|:---|
| A path segment such as `:id` | `http.require_int(request, "id")` or `http.require_string` | `Result(Int, Error)` or `Result(String, Error)` |
| A path segment, with a `String` error you map yourself | `request.get_int_param`, `request.get_string_param`, or `request.get_param` for the whole `PathParam` with its `format` | `Result(_, String)` |
| A query parameter | `request.get_query_param(request.query, "q")` | `Option(String)`, already percent-decoded |
| A JSON body, all errors at once | `request.body_as_string`, then `http.validate_json(body, decoder)` | `Result(value, List(ValidationError))` |
| A JSON body, first error only | `http.require_json(request, decoder)` | `Result(value, Error)` with a `BadRequest` message |
| A form (`application/x-www-form-urlencoded`) | `http.require_form`, then `http.require_field`, `http.require_field_int`, `http.field_optional` | The fields as a list of pairs, then each field |
| A header | `http.get_header(request.headers, "Authorization")` | `Option(String)`, name matched without case |
| A cookie | `http.get_cookie_value(request.cookies, "visits")` | `Option(String)`; see [Send responses, cookies and files](https://hexdocs.pm/dream/3.0.0/guides/responses.html) |

The `require_` helpers return Dream's `Error` type, so a controller can chain them with `use ... <- result.try(...)` and turn any failure into an answer in one place.

## Step 1: Read a path parameter

### Read an integer id <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/src/controllers/request_data_controller.gleam#L20-L30"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// GET /users/:id: the id must be a whole number
pub fn show_user(
  request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  case http.require_int(request, "id") {
    Ok(id) -> text_response(status.ok, "User " <> int.to_string(id))
    Error(error) -> response_helpers.handle_error(error)
  }
}
```

`require_int` finds the `id` that the router took from the path and parses it. A number works:

### Ask for user 42 <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/test/integration/readme.sh#L16"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
curl -i http://localhost:3000/users/42
```

### The answer for user 42 <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/test/integration/readme_output.txt#L608-L614"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
HTTP/1.1 200 OK
content-type: text/plain; charset=utf-8
content-length: 7
date: (the time of the request)
connection: keep-alive

User 42
```

A word doesn't. The error carries a message, and `response_helpers.handle_error` turns it into a `400`:

### Ask for user abc <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/test/integration/readme.sh#L18"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
curl -i http://localhost:3000/users/abc
```

### The answer for user abc <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/test/integration/readme_output.txt#L615-L621"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
HTTP/1.1 400 Bad Request
content-type: text/plain; charset=utf-8
content-length: 34
date: (the time of the request)
connection: keep-alive

Bad Request: id must be an integer
```

## Step 2: Read the query string

`request.query` is the raw query string. `get_query_param` finds one parameter in it and decodes `%20` and friends:

### Read the q parameter <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/src/controllers/request_data_controller.gleam#L32-L46"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// GET /search?q=...: the q parameter is required
pub fn search(
  request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  case get_query_param(request.query, "q") {
    Some(term) -> text_response(status.ok, "Results for " <> term)
    None ->
      text_response(
        status.bad_request,
        "Bad Request: the q parameter is missing",
      )
  }
}
```

### Search with and without q <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/test/integration/readme.sh#L20-L22"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
curl -i "http://localhost:3000/search?q=gleam%20web"
echo
curl -i http://localhost:3000/search
```

### The two answers <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/test/integration/readme_output.txt#L622-L635"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
HTTP/1.1 200 OK
content-type: text/plain; charset=utf-8
content-length: 21
date: (the time of the request)
connection: keep-alive

Results for gleam web
HTTP/1.1 400 Bad Request
content-type: text/plain; charset=utf-8
content-length: 39
date: (the time of the request)
connection: keep-alive

Bad Request: the q parameter is missing
```

A query parameter is always optional from the router's point of view: the route `/search` matches with or without it. The controller decides what a missing value means, here a `400`. For an optional parameter with a default, use `option.unwrap(get_query_param(request.query, "page"), "1")`.

## Step 3: Validate a JSON body and report every error

A client that sends three wrong fields wants to hear about all three, not fix one and try again. Decode the body with a `gleam/dynamic/decode` decoder through `http.validate_json`: it runs the whole decoder and returns one `ValidationError` for each field that failed.

### Decode a signup and answer every error <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/src/controllers/request_data_controller.gleam#L48-L103"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// The JSON body of POST /signups
pub type Signup {
  Signup(name: String, email: String, age: Int)
}

fn signup_decoder() -> decode.Decoder(Signup) {
  use name <- decode.field("name", decode.string)
  use email <- decode.field("email", decode.string)
  use age <- decode.field("age", decode.int)
  decode.success(Signup(name:, email:, age:))
}

/// POST /signups: a JSON body with name, email and age
pub fn create_signup(
  request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  case body_as_string(request) {
    Ok(body) -> signup_from_json(body)
    Error(Nil) ->
      text_response(status.bad_request, "Bad Request: the body is not text")
  }
}

fn signup_from_json(body: String) -> Response {
  case http.validate_json(body, signup_decoder()) {
    Ok(signup) -> json_response(status.created, signup_to_json(signup))
    Error(validation_errors) ->
      json_response(status.bad_request, errors_to_json(validation_errors))
  }
}

fn signup_to_json(signup: Signup) -> String {
  json.object([
    #("name", json.string(signup.name)),
    #("email", json.string(signup.email)),
    #("age", json.int(signup.age)),
  ])
  |> json.to_string
}

// One entry for each field that failed, so the client can fix them all at once
fn errors_to_json(validation_errors: List(ValidationError)) -> String {
  json.object([
    #("errors", json.array(validation_errors, validation_error_to_json)),
  ])
  |> json.to_string
}

fn validation_error_to_json(validation_error: ValidationError) -> json.Json {
  json.object([
    #("field", json.nullable(validation_error.field, json.string)),
    #("message", json.string(validation_error.message)),
  ])
}
```

Each `ValidationError` has a `message`, and the `field`, `expected` and `found` values when the error belongs to a field. The controller sends the field and the message of each one. A valid body comes back with `201`:

### Post a valid signup <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/test/integration/readme.sh#L24-L26"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
curl -i -X POST http://localhost:3000/signups \
  -H "Content-Type: application/json" \
  -d '{"name":"Ada","email":"ada@example.com","age":36}'
```

### The answer to a valid signup <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/test/integration/readme_output.txt#L636-L642"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
HTTP/1.1 201 Created
content-type: application/json; charset=utf-8
content-length: 49
date: (the time of the request)
connection: keep-alive

{"name":"Ada","email":"ada@example.com","age":36}
```

This body has a number for `name`, no `email` and a string for `age`. All three come back in one answer:

### Post a signup with three wrong fields <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/test/integration/readme.sh#L28-L30"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
curl -i -X POST http://localhost:3000/signups \
  -H "Content-Type: application/json" \
  -d '{"name":7,"age":"old"}'
```

### The answer lists every field <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/test/integration/readme_output.txt#L643-L649"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
HTTP/1.1 400 Bad Request
content-type: application/json; charset=utf-8
content-length: 216
date: (the time of the request)
connection: keep-alive

{"errors":[{"field":"name","message":"Expected String but found Int at name"},{"field":"email","message":"Expected Field but found Nothing at email"},{"field":"age","message":"Expected Int but found String at age"}]}
```

A missing field reads `Expected Field but found Nothing`: that's the wording of `gleam/dynamic/decode`. Broken JSON can't be decoded field by field, so it gives one error with no field:

### Post broken JSON <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/test/integration/readme.sh#L32-L34"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
curl -i -X POST http://localhost:3000/signups \
  -H "Content-Type: application/json" \
  -d '{"name":'
```

### The answer to broken JSON <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/test/integration/readme_output.txt#L650-L656"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
HTTP/1.1 400 Bad Request
content-type: application/json; charset=utf-8
content-length: 68
date: (the time of the request)
connection: keep-alive

{"errors":[{"field":null,"message":"Unexpected end of JSON input"}]}
```

When the first error is enough, `http.require_json(request, decoder)` is shorter: it returns `Error(BadRequest(message))` with the first problem, so it chains with the other `require_` helpers. The database example uses it.

## Step 4: Read a form

An HTML form posts `application/x-www-form-urlencoded` data. `require_form` parses the body into a list of name and value pairs and decodes each value. `require_field` takes a required field, and `field_optional` an optional one:

### Read a contact form <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/src/controllers/request_data_controller.gleam#L105-L123"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// POST /contact: a form with a required email and an optional topic
pub fn create_contact(
  request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  let contact = {
    use form <- result.try(http.require_form(request))
    use email <- result.try(http.require_field(form, "email"))
    let topic = option.unwrap(http.field_optional(form, "topic"), "general")
    Ok(#(email, topic))
  }

  case contact {
    Ok(#(email, topic)) ->
      text_response(status.ok, "Thanks, " <> email <> ". Topic: " <> topic)
    Error(error) -> response_helpers.handle_error(error)
  }
}
```

### Post the form with and without email <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/test/integration/readme.sh#L36-L39"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
curl -i -X POST http://localhost:3000/contact \
  -d "email=ada%40example.com&topic=billing"
echo
curl -i -X POST http://localhost:3000/contact -d "topic=billing"
```

### The two answers <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/test/integration/readme_output.txt#L657-L670"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
HTTP/1.1 200 OK
content-type: text/plain; charset=utf-8
content-length: 39
date: (the time of the request)
connection: keep-alive

Thanks, ada@example.com. Topic: billing
HTTP/1.1 400 Bad Request
content-type: text/plain; charset=utf-8
content-length: 42
date: (the time of the request)
connection: keep-alive

Bad Request: Missing required field: email
```

`%40` arrived as `@`. An empty body gives `Bad Request: Request body is empty`, and `require_field_int` gives an error when the field isn't a whole number.

## Step 5: Check business rules after decoding

A decoder checks shapes: is `price` a number? A business rule checks meaning: can a price be negative? Keep them apart. Decode first, then validate the decoded value and return a readable message:

### Decode, then validate <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/rest_api_guide_validation.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
//// REST API guide: input validation
////
//// A decoder for product data, and a check that runs on the decoded value,
//// as shown in docs/guides/request-data.md.

import gleam/dynamic/decode.{type Decoder, field, int, string, success}
import gleam/string.{is_empty}

pub type ProductData {
  ProductData(name: String, price: Int, description: String)
}

pub fn decoder() -> Decoder(ProductData) {
  use name <- field("name", string)
  use price <- field("price", int)
  use description <- field("description", string)
  success(ProductData(name, price, description))
}

// Validate after decoding
pub fn validate_product_data(data: ProductData) -> Result(ProductData, String) {
  case is_empty(data.name) {
    True -> Error("Name cannot be empty")
    False -> check_price(data)
  }
}

fn check_price(data: ProductData) -> Result(ProductData, String) {
  case data.price < 0 {
    True -> Error("Price cannot be negative")
    False -> Ok(data)
  }
}
```

The controller maps the two kinds of failure to two status codes: a body that doesn't decode is a `400` (from `require_json`), and a value that breaks a rule is a `422 Unprocessable Content`:

### Map each failure to its status <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/rest_api_guide_create.gleam#L6-L59"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/context.{type AppContext}
import dream/http.{type Request, type Response, created, json_response}
import dream/http/error.{type Error, UnprocessableContent}
import dream/http/params
import gleam/json
import gleam/result
import snippets/rest_api_guide_validation.{
  type ProductData, decoder, validate_product_data,
}

pub fn create(
  request: Request,
  _context: AppContext,
  services: Services,
) -> Response {
  let result = {
    use data <- result.try(params.require_json(request, decoder()))
    use valid_data <- result.try(
      validate_product_data(data)
      |> result.map_error(UnprocessableContent),
    )
    create_product(services, valid_data)
  }

  case result {
    Ok(product) -> json_response(created, to_json(product))
    Error(create_error) -> error_to_response(create_error)
  }
}

fn create_product(
  services: Services,
  data: ProductData,
) -> Result(Product, Error) {
  // A real app saves the product to its database here
  Ok(Product(
    id: services.next_product_id,
    name: data.name,
    price: data.price,
    description: data.description,
  ))
}

fn error_to_response(create_error: Error) -> Response {
  json_response(
    error.to_status_code(create_error),
    error_json(error.message(create_error)),
  )
}

fn error_json(message: String) -> String {
  json.object([#("error", json.string(message))])
  |> json.to_string
}
```

`error_to_response` uses `error.to_status_code` and `error.message`, so each `Error` variant gets its own status code. A negative price answers `422` with `{"error":"Price cannot be negative"}`.

## Turn errors into answers

Dream's `Error` type has one variant for each common failure, and `error.to_status_code` maps them: `BadRequest` to 400, `Unauthorized` to 401, `Forbidden` to 403, `NotFound` to 404, `Conflict` to 409, `UnprocessableContent` to 422 and `InternalServerError` to 500. The example maps them to text answers in one helper, so every controller answers errors the same way:

### One place for error answers <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/src/utilities/response_helpers.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
//// Response helper utilities
////
//// Common helpers for handling responses in controllers.

import dream/http.{type Error, type Response}
import dream/http/error
import dream/http/response.{text_response}
import dream/http/status

/// Handle Dream errors and convert to appropriate HTTP responses
pub fn handle_error(err: Error) -> Response {
  case err {
    error.BadRequest(msg) ->
      text_response(status.bad_request, "Bad Request: " <> msg)
    error.Unauthorized(_msg) ->
      text_response(status.unauthorized, "Unauthorized")
    error.Forbidden(_msg) -> text_response(status.forbidden, "Forbidden")
    error.NotFound(msg) -> text_response(status.not_found, "Not Found: " <> msg)
    error.Conflict(msg) -> text_response(status.conflict, "Conflict: " <> msg)
    error.UnprocessableContent(msg) ->
      text_response(status.unprocessable_content, "Unprocessable: " <> msg)
    error.InternalServerError(_msg) ->
      text_response(status.internal_server_error, "Internal Server Error")
  }
}
```

## Test your code

Test a controller by calling it with a request you build. This test checks the controller from the module doc of `dream/http/validation`, which answers a list of error messages:

### Test a JSON controller <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/guide_request_data_test.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
//// Request data guide: a test of a controller that validates a JSON body
////
//// The controller is test/snippets/doc_http_data_validation_module.gleam,
//// the example of the module doc of dream/http/validation.

import dream/context.{EmptyContext}
import dream/http/request.{type Request, Http, Http1, Post, Request}
import dream/http/response.{Text}
import dream/router.{EmptyServices}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import gleam/option
import snippets/doc_http_data_validation_module as users_controller

fn post_json(body: String) -> Request {
  Request(
    method: Post,
    protocol: Http,
    version: Http1,
    path: "/users",
    query: "",
    params: [],
    host: option.None,
    port: option.None,
    remote_address: option.None,
    body: request.Text(body),
    headers: [],
    cookies: [],
    content_type: option.Some("application/json"),
    content_length: option.None,
  )
}

pub fn tests() -> TestSuite {
  describe("users_controller.create", [
    it("answers 201 for a valid user", fn() {
      // Arrange
      let request =
        post_json("{\"name\":\"Ada\",\"email\":\"ada@example.com\",\"age\":36}")

      // Act
      let response =
        users_controller.create(request, EmptyContext, EmptyServices)

      // Assert
      response.status
      |> should
      |> be_equal(201)
      |> or_fail_with("a valid user should answer 201")
    }),
    it("lists every field that failed", fn() {
      // Arrange
      let request = post_json("{\"name\":7,\"age\":\"old\"}")

      // Act
      let response =
        users_controller.create(request, EmptyContext, EmptyServices)

      // Assert
      response.body
      |> should
      |> be_equal(Text(
        "{\"errors\":[\"Expected String but found Int at name\",\"Expected Field but found Nothing at email\",\"Expected Int but found String at age\"]}",
      ))
      |> or_fail_with("each failed field should have its message")
    }),
    it("answers 400 for a body that is not JSON", fn() {
      // Arrange
      let request = post_json("{\"name\":")

      // Act
      let response =
        users_controller.create(request, EmptyContext, EmptyServices)

      // Assert
      response.status
      |> should
      |> be_equal(400)
      |> or_fail_with("broken JSON should answer 400")
    }),
  ])
}
```

### The report of the test <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/outputs/guide_request_data_report.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
users_controller.create
  ✓ answers 201 for a valid user
  ✓ answers 400 for a body that is not JSON
  ✓ lists every field that failed

Summary: 3 run, 0 failed, 3 passed in 0ms
```

The second test compares the whole body, so it fails if a message changes or one goes missing. That's what you want from an API that clients parse.

## Common pitfalls

- **Only the first error reaches the client.** `require_json` stops at the first problem. Use `body_as_string` and `validate_json` when the client should see all of them.
- **A missing query parameter isn't a routing error.** `/search` matches with no query at all, so check for `None` in the controller.
- **The body is bytes, not text.** A body that isn't valid UTF-8 arrives as `Bytes`, and `body_as_string` returns `Error(Nil)`. Answer `400` for it, as `create_signup` does.
- **Decoding and validating in one step.** A decoder that checks business rules gives decode errors for rule failures, and the client can't tell a typo from a bad value. Decode, then validate.
- **A body over the size limit never reaches the controller.** The server answers `413 Content Too Large` with `Request body too large`. [Start, stop and troubleshoot the server](https://hexdocs.pm/dream/3.0.0/guides/operating.html) shows the limit and the answer.
- **The route parameter name and the controller's name differ.** `require_int(request, "id")` on a route with `:user_id` always answers `400`.

## Where to go next

- [Send responses, cookies and files](https://hexdocs.pm/dream/3.0.0/guides/responses.html): the other half of the exchange.
- [Build a database-backed JSON API](https://hexdocs.pm/dream/3.0.0/guides/database-api.html): `require_json` with a database behind it.
- [Stream responses and uploads](https://hexdocs.pm/dream/3.0.0/guides/streaming.html): bodies too big to read at once.
- The API reference of `dream/http/params` and `dream/http/validation` on [HexDocs](https://hexdocs.pm/dream/3.0.0/).
