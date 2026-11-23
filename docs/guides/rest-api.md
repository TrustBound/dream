# Production REST API

Production-ready patterns for building REST APIs with Dream.

## A JSON Endpoint

Start with one controller that returns JSON. It gets a user from `Services` and returns the user as JSON, or a `404` response when no user matches. The view function `user_to_json` keeps the JSON format apart from the data access.

### Return a user as JSON <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/readme_json_api.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

## Pagination

### Offset-based Pagination

A database model wraps a Squirrel query and returns domain types. This model from the database example lists all users:

#### Users model <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/database/src/models/user.gleam#L15-L21"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// List all users
pub fn list(db: pog.Connection) -> Result(List(User), Error) {
  case sql.list_users(db) {
    Ok(returned) -> Ok(extract_all_users(returned))
    Error(_) -> Error(InternalServerError("Database error"))
  }
}
```

For offset pagination, add `offset` and `limit` parameters to the function, and pass them to an SQL query with `OFFSET $1 LIMIT $2`.

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

## Validation

### Input Validation <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/rest_api_guide_validation.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
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

The decoder only reads the JSON. `validate_product_data` then checks the
decoded value and returns a readable message, for example
`Error("Price cannot be negative")`. Keeping the two steps apart keeps
decode errors (bad JSON, a missing field) separate from business rules.

## Error Handling

### Domain Errors <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/rest_api_guide_domain_errors.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

### Map to HTTP Status <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/rest_api_guide_create.gleam#L6-L59"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

`require_json` reads and decodes the body. When the body is not text, is
not JSON, or has a field of the wrong type, it returns `BadRequest`, so the
client gets a 400 response with the reason. The controller then runs
`validate_product_data` and maps its message to `UnprocessableContent`, so a
negative price gives a 422 response with
`{"error":"Price cannot be negative"}`. `error_to_response` then uses
`error.to_status_code` and `error.message` to build the JSON response, so
each `Error` variant gets its own status code.

## API Versioning

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

## Rate Limiting

### Rate limit middleware <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/rate_limiter/src/middleware/rate_limit_middleware.gleam#L6-L32"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/context.{type EmptyContext}
import dream/http/header.{add_header, get_header}
import dream/http/request.{type Request}
import dream/http/response.{type Response, Response, text_response}
import dream/http/status
import gleam/int
import gleam/option
import gleam/string
import services.{type Services}
import services/rate_limiter_service

/// Rate limiting middleware
/// Checks request rate for the client IP and enforces limits
pub fn rate_limit_middleware(
  request: Request,
  context: EmptyContext,
  services: Services,
  next: fn(Request, EmptyContext, Services) -> Response,
) -> Response {
  let ip = get_client_ip(request)

  case rate_limiter_service.check_and_increment(services.rate_limiter, ip) {
    Ok(status) ->
      handle_rate_limit_result(status, request, context, services, next)
    Error(_) -> handle_service_error(request, context, services, next)
  }
}
```

The middleware calls `rate_limiter_service.check_and_increment`, which keeps a count for each client IP in a `dream_ets` table. The rate limiter example allows 10 requests in each 60-second window. A request over the limit gets a 429 response with `X-RateLimit-Limit`, `X-RateLimit-Remaining` and `Retry-After` headers.

## Filtering and Sorting <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/rest_api_guide_filtering.gleam#L6-L64"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

## CORS <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/rest_api_guide_cors.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

## Health Check Endpoint <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/database/src/controllers/health_controller.gleam#L6-L32"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import context.{type DatabaseContext}
import dream/http.{type Request, type Response}
import dream/http/error.{type Error, InternalServerError}
import dream/http/response.{json_response}
import dream/http/status
import pog
import services.{type Services}

/// Report whether the app and its database are healthy
pub fn show(
  _request: Request,
  _context: DatabaseContext,
  services: Services,
) -> Response {
  case check_database(services.database.connection) {
    Ok(_) -> json_response(status.ok, "{\"status\": \"healthy\"}")
    Error(_) ->
      json_response(status.service_unavailable, "{\"status\": \"unhealthy\"}")
  }
}

fn check_database(db: pog.Connection) -> Result(Nil, Error) {
  case pog.query("SELECT 1") |> pog.execute(db) {
    Ok(_) -> Ok(Nil)
    Error(_) -> Error(InternalServerError("Database connection failed"))
  }
}
```

The database example routes `GET /health` to this controller. It returns 503 when the database does not answer `SELECT 1`.

## See Also

- [Testing](https://github.com/TrustBound/dream/blob/main/docs/guides/testing.md) - Test your API
- [Deployment](https://github.com/TrustBound/dream/blob/main/docs/guides/deployment.md) - Deploy to production
- [Lesson 3: Adding Auth](https://github.com/TrustBound/dream/blob/main/docs/learn/03-adding-auth.md) - Learn authentication and middleware

