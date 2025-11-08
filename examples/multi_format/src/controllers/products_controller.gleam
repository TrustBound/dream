//// Products controller demonstrating multi-format responses

import context.{type AppContext}
import dream/core/http/transaction.{type Request, type Response, get_param}
import dream/utilities/query
import services.{type Services}
import sql
import views/errors
import views/products/view as product_view
import gleam/option

/// Show single product - supports .json, .htmx, .csv extensions
pub fn show(
  request: Request,
  _context: AppContext,
  services: Services,
) -> Response {
  // Extract dependencies and path params first
  let assert Ok(param) = get_param(request, "id")
  let assert Ok(id) = param.as_int
  let db = services.database.connection

  case sql.get_product(db, id) |> query.first_row() {
    Ok(product) -> product_view.respond(product, param)
    Error(query.NotFound) -> errors.not_found()
    Error(query.DatabaseError) -> errors.internal_error()
  }
}

/// List products - demonstrates streaming for CSV
pub fn index(
  _request: Request,
  _context: AppContext,
  services: Services,
) -> Response {
  let db = services.database.connection
  case sql.list_products(db) |> query.all_rows() {
    Ok(products) -> product_view.respond_list(products, option.None)
    Error(_) -> errors.internal_error()
  }
}
