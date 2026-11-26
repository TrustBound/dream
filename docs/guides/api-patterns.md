[README](https://hexdocs.pm/dream/3.0.0/) > [Guides](https://hexdocs.pm/dream/3.0.0/guides/index.html) > Grow a JSON API

# Grow a JSON API

Your API answers single records. Now clients want pages of results, filters and sort orders, a way to call it from a browser on another origin, and a version number so you can change it without breaking them. They also want errors they can parse. This guide collects those patterns. Each piece is a tested snippet that runs without a database, so you can read it whole and then put the same logic behind your own models, like the ones in [Build a database-backed JSON API](https://hexdocs.pm/dream/3.0.0/guides/database-api.html).

## Table of Contents

- [What you'll build](#what-youll-build)
- [Before you start](#before-you-start)
- [Which pattern to use](#which-pattern-to-use)
- [Step 1: Return a record as JSON](#step-1-return-a-record-as-json)
- [Step 2: Page through results](#step-2-page-through-results)
- [Step 3: Give errors a status and a body](#step-3-give-errors-a-status-and-a-body)
- [Step 4: Version the API](#step-4-version-the-api)
- [Step 5: Filter, sort and allow other origins](#step-5-filter-sort-and-allow-other-origins)
- [Test your code](#test-your-code)
- [Common pitfalls](#common-pitfalls)
- [Where to go next](#where-to-go-next)

## What you'll build

- A JSON endpoint with a view function, and a `404` when nothing matches.
- Offset pagination and cursor pagination, with a `400` for a cursor the server didn't make.
- Domain errors that map to a status code and a JSON body.
- URL and header versioning, filters and sorting from the query string, and a CORS middleware.
- A test that walks the pages of a cursor.

## Before you start

You need Dream and `gleam_json`:

```sh
gleam add dream gleam_json
```

Read [Read request data safely](https://hexdocs.pm/dream/3.0.0/guides/request-data.html) first: these patterns read the query string and decode bodies.

## Which pattern to use

| Your situation | Use | Why |
|:---|:---|:---|
| A small, stable table, and clients jump to page N | Offset pagination (`?offset=20&limit=20`) | Simple, and the client can compute any page. |
| A large or changing table | Cursor pagination | A row added or deleted between pages doesn't shift the next page. |
| You must change the shape of an answer | URL versioning (`/v1/...`, `/v2/...`) | Easy to see in logs and to route. |
| The URL must stay the same | Header versioning | The client asks for a version in a header. |
| A browser app on another origin calls the API | CORS middleware | Browsers block cross-origin calls without it. |

## Step 1: Return a record as JSON

Start with one controller that returns JSON. It gets a user from `Services` and returns the user as JSON, or a `404` response when no user matches. The view function `user_to_json` keeps the JSON format apart from the data access.

#### Return a user as JSON <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/readme_json_api.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/http.{json_response, not_found, ok}
import gleam/json
import gleam/list

pub type User {
  User(id: Int, name: String)
}

pub type Services {
  Services(db: List(User))
}

pub fn get_user(_request, _context, services: Services) {
  case find_user(services.db, id: 1) {
    Ok(user) -> json_response(ok, user_to_json(user))
    Error(Nil) -> json_response(not_found, "{}")
  }
}

fn find_user(db: List(User), id id: Int) -> Result(User, Nil) {
  list.find(db, fn(user) { user.id == id })
}

fn user_to_json(user: User) -> String {
  json.object([#("id", json.int(user.id)), #("name", json.string(user.name))])
  |> json.to_string
}
```

## Step 2: Page through results

### Offset-based Pagination

A database model runs a query and returns domain types. The database example writes one `.sql` file for each query, and dream_model generates the model function from it. This query lists all users:

#### The users query <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/database/src/models/user/list.sql"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```sql
-- returns: many User
SELECT id, name, email, created_at FROM users ORDER BY id
```

For offset pagination, add `OFFSET $1 LIMIT $2` to the query, and the hint `-- params: offset, limit` to name the parameters of the generated function.

#### Products controller with offset and limit <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/rest_api_guide_pagination.gleam#L6-L55"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/context.{type AppContext}
import dream/http.{
  type Request, type Response, get_query_param, internal_server_error,
  json_response, ok,
}
import dream/http/error.{type Error}
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some, unwrap}

// controllers/products_controller.gleam
pub fn index(
  request: Request,
  _context: AppContext,
  services: Services,
) -> Response {
  let offset =
    get_query_param(request.query, "offset")
    |> parse_optional_int
    |> unwrap(0)
  let limit =
    get_query_param(request.query, "limit")
    |> parse_optional_int
    |> unwrap(20)

  case list_paginated(services.products, offset, limit) {
    Ok(products) ->
      json_response(ok, to_json_with_pagination(products, offset, limit))
    Error(_) -> internal_error_response()
  }
}

fn internal_error_response() -> Response {
  json_response(internal_server_error, "{\"error\": \"Internal server error\"}")
}

fn parse_optional_int(value: Option(String)) -> Option(Int) {
  case value {
    Some(text) -> parse_int_string(text)
    None -> None
  }
}

fn parse_int_string(text: String) -> Option(Int) {
  case int.parse(text) {
    Ok(number) -> Some(number)
    Error(_) -> None
  }
}
```

The controller reads `offset` and `limit` from the query string, for
example `GET /products?offset=20&limit=20`. To keep the tested snippet
self-contained, its `list_paginated` reads from a list in `Services`; a real
app calls a database model like the one above.

### Cursor-based Pagination

A cursor marks the last row the client saw. The client sends it back to get the next page. This model encodes the last id on the page as an opaque base64 string:

#### Products model with a cursor <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/rest_api_guide_cursor_pagination.gleam#L14-L69"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub type Product {
  Product(id: Int, name: String)
}

pub type Page {
  Page(items: List(Product), next_cursor: Option(String))
}

// models/product.gleam
pub fn list_after(
  products: List(Product),
  cursor: Option(String),
  limit: Int,
) -> Result(Page, Error) {
  case decode_cursor(cursor) {
    Ok(after_id) -> Ok(page_after(products, after_id, limit))
    Error(_) -> Error(BadRequest("Invalid cursor"))
  }
}

fn page_after(products: List(Product), after_id: Int, limit: Int) -> Page {
  // Read one row more than the page holds, to know if a next page exists
  let rows =
    products
    |> list.drop_while(is_at_or_before(_, after_id))
    |> list.take(limit + 1)
  let items = list.take(rows, limit)
  case list.length(rows) > limit, list.last(items) {
    True, Ok(last) -> Page(items, Some(encode_cursor(last.id)))
    _, _ -> Page(items, None)
  }
}

fn is_at_or_before(product: Product, after_id: Int) -> Bool {
  product.id <= after_id
}

fn encode_cursor(id: Int) -> String {
  int.to_string(id)
  |> bit_array.from_string
  |> bit_array.base64_url_encode(False)
}

fn decode_cursor(cursor: Option(String)) -> Result(Int, Nil) {
  case cursor {
    // No cursor: start before the first id
    None -> Ok(0)
    Some(text) -> parse_cursor(text)
  }
}

fn parse_cursor(text: String) -> Result(Int, Nil) {
  use bits <- result.try(bit_array.base64_url_decode(text))
  use digits <- result.try(bit_array.to_string(bits))
  int.parse(digits)
}
```

The model reads one row more than `limit`. If that extra row exists, the page gets a `next_cursor`. The last page has no `next_cursor`. A cursor that does not decode to an id gives a `BadRequest` error.

To keep the tested snippet self-contained, `list_after` reads from a list. A real app runs the same logic in SQL: `WHERE id > $1 ORDER BY id LIMIT $2`, with `$2` set to `limit + 1`.

## Step 3: Give errors a status and a body

### Domain errors <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/rest_api_guide_domain_errors.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/http/error.{type Error, NotFound}

pub type Product {
  Product(id: Int, name: String)
}

// Use Dream's Error type instead of custom error types.
// This keeps error handling consistent across the application.
pub fn find_product(
  products: List(Product),
  id: Int,
) -> Result(Product, Error) {
  case products {
    [] -> Error(NotFound("Product not found"))
    [product, ..] if product.id == id -> Ok(product)
    [_product, ..rest] -> find_product(rest, id)
  }
}
```

### One place for error answers

Dream uses a unified error type (`dream.Error`) across the framework and application. The operations map the data errors of the generated models to it, so controllers handle one error type and stay thin.

**Response Helpers Pattern:**

Create a `utilities/response_helpers.gleam` module to centralize error handling:

##### A response helpers module <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/controllers_guide_response_helpers.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/http.{
  type Response, bad_request, conflict, forbidden, gateway_timeout,
  internal_server_error, json_response, not_found, service_unavailable,
  unauthorized, unprocessable_content,
}
import dream/http/error.{
  type Error, BadRequest, Conflict, Forbidden, GatewayTimeout,
  InternalServerError, NotFound, ServiceUnavailable, Unauthorized,
  UnprocessableContent,
}
import gleam/json.{object, string, to_string}

pub fn handle_error(err: Error) -> Response {
  case err {
    BadRequest(msg) -> json_response(bad_request, error_json(msg))
    Unauthorized(_msg) ->
      json_response(unauthorized, error_json("Unauthorized"))
    Forbidden(_msg) -> json_response(forbidden, error_json("Forbidden"))
    NotFound(msg) -> json_response(not_found, error_json(msg))
    Conflict(msg) -> json_response(conflict, error_json(msg))
    UnprocessableContent(msg) ->
      json_response(unprocessable_content, error_json(msg))
    InternalServerError(_msg) ->
      json_response(internal_server_error, error_json("Internal server error"))
    ServiceUnavailable(_msg) ->
      json_response(service_unavailable, error_json("Service unavailable"))
    GatewayTimeout(_msg) ->
      json_response(gateway_timeout, error_json("Timed out"))
  }
}

fn error_json(message: String) -> String {
  object([#("error", string(message))])
  |> to_string()
}
```

This pattern:
- **Centralizes error handling:** One place to update error response formats
- **Consistent responses:** All errors follow the same structure
- **Easy to customize:** Modify error messages or formats in one place
- **Type-safe:** Compile-time checking ensures all error cases are handled

Controllers simply call `response_helpers.handle_error(err)` instead of handling each error type individually.

## Step 4: Version the API

### URL-based Versioning <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/rest_api_guide_url_versioning.gleam#L15-L20"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
// router.gleam
pub fn create_router() -> Router(AppContext, Services) {
  router()
  |> route(Get, "/v1/products", list_products_v1, [])
  |> route(Get, "/v2/products", list_products_v2, [])
}
```

### Header-based Versioning <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/rest_api_guide_header_versioning.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/context.{type AppContext}
import dream/http.{
  type Request, type Response, bad_request, get_header, json_response, ok,
}
import gleam/option.{unwrap}

pub type Services {
  Services
}

pub fn index(
  request: Request,
  _context: AppContext,
  services: Services,
) -> Response {
  let version =
    get_header(request.headers, "API-Version")
    |> unwrap("1")

  case version {
    "1" -> v1_index(services)
    "2" -> v2_index(services)
    _ -> json_response(bad_request, "{\"error\": \"Unsupported API version\"}")
  }
}

// Implement version-specific controllers
fn v1_index(_services: Services) -> Response {
  json_response(ok, "{\"version\": \"1\"}")
}

fn v2_index(_services: Services) -> Response {
  json_response(ok, "{\"version\": \"2\"}")
}
```

## Step 5: Filter, sort and allow other origins

### Filtering and sorting <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/rest_api_guide_filtering.gleam#L6-L64"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/context.{type AppContext}
import dream/http.{
  type Request, type Response, get_query_param, internal_server_error,
  json_response, ok,
}
import dream/http/error.{type Error}
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order.{type Order}
import gleam/string

pub fn index(
  request: Request,
  _context: AppContext,
  services: Services,
) -> Response {
  let filters = parse_filters(request.query)
  let sort = parse_sort(request.query)

  case list_filtered(services.products, filters, sort) {
    Ok(products) -> json_response(ok, list_to_json(products))
    Error(_) -> internal_error_response()
  }
}

fn parse_filters(query: String) -> ProductFilters {
  ProductFilters(
    category: get_query_param(query, "category"),
    min_price: parse_optional_int(get_query_param(query, "min_price")),
    max_price: parse_optional_int(get_query_param(query, "max_price")),
  )
}

fn parse_sort(query: String) -> ProductSort {
  case get_query_param(query, "sort") {
    Some("price") -> SortByPrice
    _ -> SortByName
  }
}

fn parse_optional_int(value: Option(String)) -> Option(Int) {
  case value {
    Some(text) -> parse_int_string(text)
    None -> None
  }
}

fn parse_int_string(text: String) -> Option(Int) {
  case int.parse(text) {
    Ok(number) -> Some(number)
    Error(_) -> None
  }
}

fn internal_error_response() -> Response {
  json_response(internal_server_error, "{\"error\": \"Internal server error\"}")
}
```

### CORS <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/rest_api_guide_cors.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/context.{type AppContext}
import dream/http/header.{Header}
import dream/http/request.{type Request}
import dream/http/response.{type Response, Response}

pub type Services {
  Services
}

pub fn cors_middleware(
  request: Request,
  context: AppContext,
  services: Services,
  next: fn(Request, AppContext, Services) -> Response,
) -> Response {
  let response = next(request, context, services)

  add_cors_headers(response)
}

fn add_cors_headers(response: Response) -> Response {
  Response(..response, headers: [
    Header("Access-Control-Allow-Origin", "*"),
    Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS"),
    Header("Access-Control-Allow-Headers", "Content-Type, Authorization"),
    ..response.headers
  ])
}
```

## Test your code

The cursor model is a pure function, so its test needs no server and no database. This test walks the pages: the first page, the page its cursor points to, and a cursor the server never made:

### Test cursor pagination <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/guide_api_patterns_test.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
//// API patterns guide: a test of cursor pagination
////
//// The model is list_after of test/snippets/rest_api_guide_cursor_pagination.gleam.

import dream/http/error.{type Error, BadRequest}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import gleam/option.{None}
import gleam/result
import snippets/rest_api_guide_cursor_pagination.{type Page, Page, Product}

fn products() -> List(rest_api_guide_cursor_pagination.Product) {
  [Product(1, "Desk"), Product(2, "Lamp"), Product(3, "Chair")]
}

// The first page, then the page that its cursor points to
fn second_page() -> Result(Page, Error) {
  use first <- result.try(rest_api_guide_cursor_pagination.list_after(
    products(),
    None,
    2,
  ))
  rest_api_guide_cursor_pagination.list_after(products(), first.next_cursor, 2)
}

pub fn tests() -> TestSuite {
  describe("list_after", [
    it("gives the first two products on the first page", fn() {
      // Act
      let page =
        rest_api_guide_cursor_pagination.list_after(products(), None, 2)

      // Assert
      page
      |> result.map(fn(first) { first.items })
      |> should
      |> be_equal(Ok([Product(1, "Desk"), Product(2, "Lamp")]))
      |> or_fail_with("the first page should hold products 1 and 2")
    }),
    it("gives the rest, and no cursor, on the last page", fn() {
      // Act
      let page = second_page()

      // Assert
      page
      |> should
      |> be_equal(Ok(Page(items: [Product(3, "Chair")], next_cursor: None)))
      |> or_fail_with("the second page should hold product 3 and end the list")
    }),
    it("refuses a cursor that it did not make", fn() {
      // Act
      let page =
        rest_api_guide_cursor_pagination.list_after(
          products(),
          option.Some("not-a-cursor"),
          2,
        )

      // Assert
      page
      |> should
      |> be_equal(Error(BadRequest("Invalid cursor")))
      |> or_fail_with("a made-up cursor should give BadRequest")
    }),
  ])
}
```

### The report of the test <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/outputs/guide_api_patterns_report.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
list_after
  ✓ gives the first two products on the first page
  ✓ gives the rest, and no cursor, on the last page
  ✓ refuses a cursor that it did not make

Summary: 3 run, 0 failed, 3 passed in 0ms
```

## Common pitfalls

- **Offset pages skip or repeat rows.** If a row is inserted before the current offset between two requests, every later page shifts by one. Use a cursor for tables that change.
- **A cursor that the client can read and edit.** Base64 hides nothing. Treat a cursor as untrusted input: decode it, and answer `400` for anything you didn't make, as `list_after` does.
- **No upper limit on `limit`.** A client can ask for a million rows. Clamp `limit` in the controller.
- **CORS headers only on success.** The browser also needs them on the error answers, or it shows a CORS error in place of your message.
- **`Access-Control-Allow-Origin: *` with cookies.** Browsers refuse credentials with a wildcard origin. Name the origin.

## Where to go next

- [Build a database-backed JSON API](https://hexdocs.pm/dream/3.0.0/guides/database-api.html): the same patterns with PostgreSQL behind them.
- [Route requests and add middleware](https://hexdocs.pm/dream/3.0.0/guides/routing.html): middleware such as CORS and rate limits.
- [Render HTML and other formats](https://hexdocs.pm/dream/3.0.0/guides/templates.html).
- The API reference on [HexDocs](https://hexdocs.pm/dream/3.0.0/).
