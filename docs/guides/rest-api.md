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

```gleam
import dream/http.{type Request, type Response, json_response, ok, internal_server_error, get_query_param}
import dream/context.{AppContext}
import gleam/int
import gleam/option.{Option, None, Some, unwrap}
import models/product.{list_paginated}
import services.{Services}
import views/product_view.{to_json_with_pagination}

// controllers/products_controller.gleam
pub fn index(request: Request, context: AppContext, services: Services) -> Response {
  let offset = get_query_param(request, "offset") |> parse_optional_int |> unwrap(0)
  let limit = get_query_param(request, "limit") |> parse_optional_int |> unwrap(20)
  
  case list_paginated(services.db, offset, limit) {
    Ok(products) -> json_response(ok, to_json_with_pagination(products, offset, limit))
    Error(_) -> internal_error_response()
  }
}

fn internal_error_response() -> Response {
  json_response(internal_server_error, "{\"error\": \"Internal server error\"}")
}

fn parse_optional_int(value: Option(String)) -> Option(Int) {
  case value {
    Some(str) -> parse_int_string(str)
    None -> None
  }
}

fn parse_int_string(str: String) -> Option(Int) {
  case int.parse(str) {
    Ok(num) -> Some(num)
    Error(_) -> None
  }
}
```

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

### Input Validation

```gleam
import gleam/dynamic/decode.{Decoder, field, string, int, success, failure}
import gleam/string.{is_empty}

pub type ProductData {
  ProductData(name: String, price: Int, description: String)
}

pub fn decoder() -> Decoder(ProductData) {
  use name <- field("name", string)
  use price <- field("price", int)
  use description <- field("description", string)
  
  // Validate after decoding
  case validate_product_data(name, price, description) {
    Ok(data) -> success(data)
    Error(msg) -> failure(msg, "ProductData")
  }
}

fn validate_product_data(
  name: String,
  price: Int,
  description: String,
) -> Result(ProductData, String) {
  case is_empty(name) {
    True -> Error("Name cannot be empty")
    False -> check_price(price, name, description)
  }
}

fn check_price(price: Int, name: String, description: String) -> Result(ProductData, String) {
  case price < 0 {
    True -> Error("Price cannot be negative")
    False -> Ok(ProductData(name, price, description))
  }
}
```

## Error Handling

### Domain Errors

```gleam
// Note: Use dream.Error instead of custom error types
// This keeps error handling consistent across the application
// import dream/http/error.{type Error, NotFound, UnprocessableContent, InternalServerError}
```

### Map to HTTP Status

```gleam
import dream/http.{type Request, type Response, json_response, created, bad_request, unprocessable_content, not_found, internal_server_error, validate_json}
import dream/context.{AppContext}
import gleam/int.{to_string}
import dream/http/error.{type Error, UnprocessableContent, NotFound, InternalServerError}
import gleam/result
import models/product.{decoder, create}
import services.{Services}
import utilities/response_helpers
import views/product_view.{to_json}

pub fn create(request: Request, context: AppContext, services: Services) -> Response {
  let result = {
    use data <- result.try(validate_json(request.body, decoder()))
    create_product(services, data)
  }
  
  case result {
    Ok(product) -> json_response(created, to_json(product))
    Error(err) -> response_helpers.handle_error(err)
  }
}

fn create_product(services: Services, data: ProductData) -> Result(Product, Error) {
  let db = services.database.connection
  create(db, data)
}

fn error_json(message: String) -> String {
  "{\"error\": \"" <> message <> "\"}"
}
```

## API Versioning

### URL-based Versioning

```gleam
// router.gleam
router()
|> route(Get, "/v1/products", v1.products_controller.index, [])
|> route(Get, "/v2/products", v2.products_controller.index, [])
```

### Header-based Versioning

```gleam
import dream/http.{type Request, type Response, json_response, ok, bad_request, get_header}
import dream/context.{AppContext}
import gleam/option.{unwrap}
import services.{Services}

pub fn index(request: Request, context: AppContext, services: Services) -> Response {
  let version = get_header(request.headers, "API-Version")
    |> unwrap("1")
  
  case version {
    "1" -> v1_index(services)
    "2" -> v2_index(services)
    _ -> json_response(bad_request, "{\"error\": \"Unsupported API version\"}")
  }
}

// Implement version-specific controllers
fn v1_index(services: Services) -> Response {
  json_response(ok, "{\"version\": \"1\"}")
}

fn v2_index(services: Services) -> Response {
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

## Filtering and Sorting

```gleam
import dream/http.{type Request, type Response, json_response, ok}
import dream/context.{AppContext}
import gleam/int
import gleam/list.{List}
import gleam/option.{Option, None, Some}
import models/product.{list_filtered, ProductFilters}
import services.{Services}
import views/product_view.{list_to_json}

pub fn index(request: Request, context: AppContext, services: Services) -> Response {
  let filters = parse_filters(request.query)  // Helper: parse query string into filters
  let sort = parse_sort(request.query)  // Helper: parse sort parameters
  
  case list_filtered(services.db, filters, sort) {
    Ok(products) -> json_response(ok, list_to_json(products))
    Error(_) -> internal_error_response()
  }
}

fn parse_filters(query: List(#(String, String))) -> ProductFilters {
  ProductFilters(
    category: get_query_value(query, "category"),
    min_price: parse_optional_int(get_query_value(query, "min_price")),
    max_price: parse_optional_int(get_query_value(query, "max_price")),
  )
}

fn parse_optional_int(value: Option(String)) -> Option(Int) {
  case value {
    Some(str) -> parse_int_string(str)
    None -> None
  }
}

fn parse_int_string(str: String) -> Option(Int) {
  case int.parse(str) {
    Ok(num) -> Some(num)
    Error(_) -> None
  }
}
```

## CORS

```gleam
import dream/http.{type Request, type Response}
import dream/http/header.{Header}
import dream/context.{AppContext}
import services.{Services}

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
  Response(
    ..response,
    headers: [
      Header("Access-Control-Allow-Origin", "*"),
      Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS"),
      Header("Access-Control-Allow-Headers", "Content-Type, Authorization"),
      ..response.headers
    ]
  )
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

