//// REST API guide: filtering and sorting
////
//// A products controller that filters and sorts with query parameters, as
//// shown in docs/guides/rest-api.md.

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

// services.gleam, models/product.gleam and views/product_view.gleam

pub type Product {
  Product(name: String, category: String, price: Int)
}

pub type ProductFilters {
  ProductFilters(
    category: Option(String),
    min_price: Option(Int),
    max_price: Option(Int),
  )
}

pub type ProductSort {
  SortByName
  SortByPrice
}

pub type Services {
  Services(products: List(Product))
}

pub fn list_filtered(
  products: List(Product),
  filters: ProductFilters,
  sort: ProductSort,
) -> Result(List(Product), Error) {
  // A real app filters and sorts in its database query here
  products
  |> list.filter(matches_filters(_, filters))
  |> list.sort(compare_products(sort))
  |> Ok
}

fn matches_filters(product: Product, filters: ProductFilters) -> Bool {
  matches_category(product, filters.category)
  && is_at_least(product.price, filters.min_price)
  && is_at_most(product.price, filters.max_price)
}

fn matches_category(product: Product, category: Option(String)) -> Bool {
  case category {
    Some(name) -> product.category == name
    None -> True
  }
}

fn is_at_least(price: Int, min_price: Option(Int)) -> Bool {
  case min_price {
    Some(minimum) -> price >= minimum
    None -> True
  }
}

fn is_at_most(price: Int, max_price: Option(Int)) -> Bool {
  case max_price {
    Some(maximum) -> price <= maximum
    None -> True
  }
}

fn compare_products(sort: ProductSort) -> fn(Product, Product) -> Order {
  case sort {
    SortByName -> compare_by_name
    SortByPrice -> compare_by_price
  }
}

fn compare_by_name(first: Product, second: Product) -> Order {
  string.compare(first.name, second.name)
}

fn compare_by_price(first: Product, second: Product) -> Order {
  int.compare(first.price, second.price)
}

fn list_to_json(products: List(Product)) -> String {
  json.array(products, product_to_json)
  |> json.to_string
}

fn product_to_json(product: Product) -> json.Json {
  json.object([
    #("name", json.string(product.name)),
    #("category", json.string(product.category)),
    #("price", json.int(product.price)),
  ])
}
