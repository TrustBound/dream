//// REST API guide: offset-based pagination
////
//// A products controller that reads `offset` and `limit` from the query
//// string, as shown in docs/guides/rest-api.md.

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

// services.gleam, models/product.gleam and views/product_view.gleam

pub type Product {
  Product(id: Int, name: String)
}

pub type Services {
  Services(products: List(Product))
}

pub fn list_paginated(
  products: List(Product),
  offset: Int,
  limit: Int,
) -> Result(List(Product), Error) {
  // A real app reads one page of rows from its database here
  products
  |> list.drop(offset)
  |> list.take(limit)
  |> Ok
}

pub fn to_json_with_pagination(
  products: List(Product),
  offset: Int,
  limit: Int,
) -> String {
  json.object([
    #("data", json.array(products, product_to_json)),
    #("offset", json.int(offset)),
    #("limit", json.int(limit)),
  ])
  |> json.to_string
}

fn product_to_json(product: Product) -> json.Json {
  json.object([
    #("id", json.int(product.id)),
    #("name", json.string(product.name)),
  ])
}
