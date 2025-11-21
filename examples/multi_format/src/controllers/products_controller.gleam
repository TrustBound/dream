//// Products controller demonstrating multi-format responses
////
//// Handles HTTP concerns: parsing, error mapping, response building.

import context.{type AppContext}
import dream/http.{type Request, type Response}
import dream/http/error.{type Error, BadRequest}
import dream/http/request.{type PathParam, get_param}
import dream/http/response.{html_response, json_response, text_response}
import dream/http/status
import gleam/option
import gleam/result
import operations/product_operations
import services.{type Services}
import types/product.{type Product}
import utilities/response_helpers
import views/products/view as product_view

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
    use product <- result.try(product_operations.get_product(db, id))
    Ok(#(product, format))
  }

  case result {
    Ok(#(product, format)) -> respond_with_format(product, format)
    Error(err) -> response_helpers.handle_error(err)
  }
}

fn respond_with_format(
  product: Product,
  format: option.Option(String),
) -> Response {
  case format {
    option.Some("json") ->
      json_response(status.ok, product_view.to_json(product))
    option.Some("htmx") ->
      html_response(status.ok, product_view.to_htmx(product))
    option.Some("csv") -> text_response(status.ok, product_view.to_csv(product))
    _ -> html_response(status.ok, product_view.to_html(product))
  }
}

/// List products - demonstrates streaming for CSV
pub fn index(
  _request: Request,
  _context: AppContext,
  services: Services,
) -> Response {
  let result = {
    let db = services.database.connection
    product_operations.list_products(db)
  }

  case result {
    Ok(products) ->
      html_response(status.ok, product_view.list_to_html(products))
    Error(err) -> response_helpers.handle_error(err)
  }
}
