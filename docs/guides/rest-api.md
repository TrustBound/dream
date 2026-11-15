# Production REST API

Production-ready patterns for building REST APIs with Dream.

## Pagination

### Offset-based Pagination

```gleam
import dream/http/error.{type Error, InternalServerError}
import gleam/list.{List, map}
import pog.{Connection, Returned}
import sql
import types/product.{Product}

// models/product.gleam
pub fn list_paginated(
  db: Connection,
  offset: Int,
  limit: Int,
) -> Result(List(Product), Error) {
  case sql.list_products_paginated(db, offset, limit) {
    Ok(returned) -> Ok(map(returned.rows, row_to_product))
    Error(_) -> Error(InternalServerError("Database error"))
  }
}
```

#### Products controller with offset and limit <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/rest_api_guide_pagination.gleam#L6-L55"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

```gleam
import dream/http/error.{type Error}
import gleam/list.{List}
import gleam/option.{Option, None, Some}
import pog.{Connection}
import types/product.{Product}

pub fn list_after(
  db: Connection,
  after_id: Option(Int),
  limit: Int,
) -> Result(List(Product), Error) {
  case after_id {
    None -> sql.list_products(db, limit)
    Some(id) -> sql.list_products_after(db, id, limit)
  }
}
```

## Validation

### Input Validation <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/rest_api_guide_validation.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

### Domain Errors <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/rest_api_guide_domain_errors.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

### Map to HTTP Status <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/rest_api_guide_create.gleam#L6-L68"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/context.{type AppContext}
import dream/http.{
  type Request, type Response, type ValidationError, created, json_response,
  validate_json,
}
import dream/http/error.{type Error, UnprocessableContent}
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
    use data <- result.try(
      validate_json(request.body, decoder())
      |> result.map_error(validation_error_to_error),
    )
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

fn validation_error_to_error(validation_error: ValidationError) -> Error {
  UnprocessableContent(validation_error.message)
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

`validate_json` returns a `ValidationError`, so the controller maps it to
`UnprocessableContent` first. It then runs `validate_product_data` and maps
its message to `UnprocessableContent` too, so a negative price gives a 422
response with `{"error":"Price cannot be negative"}`. `error_to_response` then uses
`error.to_status_code` and `error.message` to build the JSON response, so
each `Error` variant gets its own status code.

## API Versioning

### URL-based Versioning <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/rest_api_guide_url_versioning.gleam#L15-L20"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
// router.gleam
pub fn create_router() -> Router(AppContext, Services) {
  router()
  |> route(Get, "/v1/products", list_products_v1, [])
  |> route(Get, "/v2/products", list_products_v2, [])
}
```

### Header-based Versioning <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/rest_api_guide_header_versioning.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

```gleam
import dream/http.{type Request, type Response, json_response, too_many_requests}
import dream/context.{AppContext}
import dream_ets
import services.{Services}

pub fn rate_limit_middleware(
  request: Request,
  context: AppContext,
  services: Services,
  next: fn(Request, AppContext, Services) -> Response,
) -> Response {
  let ip = get_client_ip(request)  // Helper: extract IP from request.remote_address
  let key = "rate_limit:" <> ip
  
  case dream_ets.get(services.cache, key) {
    Ok(count) if count >= 100 ->
      json_response(too_many_requests, "{\"error\": \"Rate limit exceeded\"}")
    Ok(count) -> {
      let _ = dream_ets.set(services.cache, key, count + 1)
      next(request, context, services)
    }
    Error(_) -> {
      let _ = dream_ets.set(services.cache, key, 1)
      next(request, context, services)
    }
  }
}

fn error_json(message: String) -> String {
  "{\"error\": \"" <> message <> "\"}"
}
```

## Filtering and Sorting <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/rest_api_guide_filtering.gleam#L6-L64"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

## CORS <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/rest_api_guide_cors.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

## Health Check Endpoint

```gleam
import dream/http.{type Request, type Response, json_response, ok, service_unavailable}
import dream/context.{AppContext}
import pog.{Connection, query}
import services.{Services}
import dream/http/error.{type Error, InternalServerError}

pub fn health_check(
  _request: Request,
  _context: AppContext,
  services: Services,
) -> Response {
  case check_database(services.db) {
    Ok(_) -> json_response(ok, "{\"status\": \"healthy\"}")
    Error(_) -> json_response(service_unavailable, "{\"status\": \"unhealthy\"}")
  }
}

fn check_database(db: Connection) -> Result(Nil, Error) {
  case query("SELECT 1", db, []) {
    Ok(_) -> Ok(Nil)
    Error(_) -> Error(InternalServerError("Database connection failed"))
  }
}
```

## See Also

- [Testing](testing.md) - Test your API
- [Deployment](deployment.md) - Deploy to production
- [Lesson 3: Adding Auth](../learn/03-adding-auth.md) - Learn authentication and middleware

