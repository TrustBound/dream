//// Products controller demonstrating multi-format responses
////
//// Handles HTTP concerns: parsing, error mapping, response building.

import context.{type AppContext}
import dream/core/http/response.{
  html_response, json_response, stream_response, text_response,
}
import dream/core/http/status
import dream/core/http/transaction.{type Request, type Response, get_param}
import models/product as product_model
import services.{type Services}
import types/errors
import types/product
import views/errors as error_responses
import views/products/view as product_view
import gleam/option

/// Show single product - supports .json, .htmx, .csv extensions
pub fn show(
  request: Request,
  _context: AppContext,
  services: Services,
) -> Response {
  let assert Ok(param) = get_param(request, "id")
  let assert Ok(id) = param.as_int

  let db = services.database.connection
  case product_model.get(db, id) {
    Ok(product) -> respond_with_format(product, param.format)
    Error(errors.NotFound) -> error_responses.not_found("Product not found")
    Error(_) -> error_responses.internal_error()
  }
}

fn respond_with_format(
  product: product.Product,
  format: option.Option(String),
) -> Response {
  case format {
    option.Some("json") -> json_response(status.ok, product_view.to_json(product))
    option.Some("htmx") -> html_response(status.ok, product_view.to_htmx(product))
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
  let db = services.database.connection
  case product_model.list(db) {
    Ok(products) -> html_response(status.ok, product_view.list_to_html(products))
    Error(_) -> error_responses.internal_error()
  }
}
