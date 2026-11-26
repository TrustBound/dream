//// Products controller demonstrating multi-format responses
////
//// Handles HTTP concerns: parsing, error mapping, response building.

import context.{type AppContext}
import dream/http.{type Request, type Response}
import dream/http/error.{type Error, BadRequest}
import dream/http/request.{type PathParam, get_param}
import dream/http/response.{
  html_response, json_response, stream_response, text_response,
}
import dream/http/status.{ok}
import gleam/option.{type Option, Some}
import gleam/result
import gleam/string.{ends_with}
import models/product.{type Product}
import operations/product_operations.{get_product, list_products}
import services.{type Services}
import utilities/response_helpers.{handle_error}
import views/products/view.{
  list_to_csv_stream, list_to_html, list_to_json, to_csv, to_html, to_htmx,
  to_json,
}

fn parse_int_param(param: PathParam) -> Result(Int, Error) {
  case param.as_int {
    Ok(i) -> Ok(i)
    Error(_) -> Error(BadRequest("id must be an integer"))
  }
}

fn map_param_error(msg: String) -> Error {
  BadRequest(msg)
}

/// Show single product - supports .json, .htmx, .csv extensions
pub fn show(
  request: Request,
  _context: AppContext,
  services: Services,
) -> Response {
  let result = {
    use param <- result.try(result.map_error(
      get_param(request, "id"),
      map_param_error,
    ))
    use id <- result.try(parse_int_param(param))
    let format = param.format
    let db = services.database.connection
    use product <- result.try(get_product(db, id))
    Ok(#(product, format))
  }

  case result {
    Ok(#(product, format)) -> respond_with_format(product, format)
    Error(err) -> handle_error(err)
  }
}

fn respond_with_format(product: Product, format: Option(String)) -> Response {
  case format {
    Some("json") -> json_response(ok, to_json(product))
    Some("htmx") -> html_response(ok, to_htmx(product))
    Some("csv") -> text_response(ok, to_csv(product))
    _ -> html_response(ok, to_html(product))
  }
}

/// List products - demonstrates streaming for CSV
pub fn index(
  request: Request,
  _context: AppContext,
  services: Services,
) -> Response {
  let result = {
    let db = services.database.connection
    list_products(db)
  }

  case result {
    Ok(products) -> respond_with_format_from_path(products, request.path)
    Error(err) -> handle_error(err)
  }
}

fn respond_with_format_from_path(
  products: List(Product),
  path: String,
) -> Response {
  case ends_with(path, ".json") {
    True -> json_response(ok, list_to_json(products))
    False -> respond_html_or_csv(products, path)
  }
}

fn respond_html_or_csv(products: List(Product), path: String) -> Response {
  case ends_with(path, ".csv") {
    True -> stream_response(ok, list_to_csv_stream(products), "text/csv")
    False -> html_response(ok, list_to_html(products))
  }
}
