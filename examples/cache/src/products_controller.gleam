//// The product routes: read a product through the cache, and change its
//// price.

import catalog.{type CatalogError, type Product, StoreFailed, UnknownProduct}
import clock
import dream/context.{type EmptyContext}
import dream/http/error
import dream/http/header.{add_header}
import dream/http/params.{require_string}
import dream/http/request.{type Request}
import dream/http/response.{
  type Response, Response, empty_response, text_response,
}
import dream/http/status
import gleam/int
import gleam/result
import gleam/string
import product_cache.{Hit, Miss}
import services.{type Services}

/// `GET /products/:id`: the product, with an `x-cache` header that says
/// `hit` or `miss`
pub fn show(
  request: Request,
  _context: EmptyContext,
  services: Services,
) -> Response {
  case require_string(request, "id") {
    Ok(id) -> show_product(services, id)
    Error(problem) ->
      text_response(error.to_status_code(problem), error.message(problem))
  }
}

fn show_product(services: Services, id: String) -> Response {
  let now = clock.read_time(services.clock)
  case product_cache.find_product(services.cache, services.catalog, id, now) {
    Ok(Hit(product)) -> product_response(product, "hit")
    Ok(Miss(product)) -> product_response(product, "miss")
    Error(problem) -> error_response(problem)
  }
}

/// `PUT /products/:id` with a price in cents as the body: changes the price
/// in the catalog, then removes the product from the cache
pub fn update(
  request: Request,
  _context: EmptyContext,
  services: Services,
) -> Response {
  case read_price_change(request) {
    Ok(#(id, price_in_cents)) -> change_price(services, id, price_in_cents)
    Error(message) -> text_response(status.bad_request, message)
  }
}

fn read_price_change(request: Request) -> Result(#(String, Int), String) {
  use id <- result.try(
    require_string(request, "id") |> result.map_error(error.message),
  )
  use body <- result.try(
    request.body_as_string(request)
    |> result.replace_error("The body is not text"),
  )
  use price_in_cents <- result.map(
    int.parse(string.trim(body))
    |> result.replace_error("The body must be a price in cents"),
  )
  #(id, price_in_cents)
}

fn change_price(
  services: Services,
  id: String,
  price_in_cents: Int,
) -> Response {
  let changed = {
    use _product <- result.try(catalog.change_price(
      services.catalog,
      id,
      price_in_cents,
    ))
    product_cache.forget_product(services.cache, id)
  }
  case changed {
    Ok(Nil) -> empty_response(status.no_content)
    Error(problem) -> error_response(problem)
  }
}

fn product_response(product: Product, cache_result: String) -> Response {
  let response =
    text_response(
      status.ok,
      product.name <> ": " <> int.to_string(product.price_in_cents) <> " cents",
    )
  Response(
    ..response,
    headers: add_header(response.headers, "x-cache", cache_result),
  )
}

fn error_response(problem: CatalogError) -> Response {
  case problem {
    UnknownProduct(id:) -> text_response(status.not_found, "No product " <> id)
    StoreFailed(reason:) ->
      text_response(
        status.internal_server_error,
        "The product store failed: " <> reason,
      )
  }
}
