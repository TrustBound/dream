//// Products controller demonstrating multi-format responses

import context.{type AppContext}
import dream/core/http/statuses.{
  bad_request_status, internal_server_error_status, not_found_status,
}
import dream/core/http/transaction.{type Request, type Response, get_param, html_response}
import dream/utilities/query
import services.{type Services}
import sql
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
  case sql.get_product(db, id) |> query.first_row() {
    Ok(product) -> product_view.respond(product, param)
    Error(query.NotFound) -> not_found_response()
    Error(query.DatabaseError) -> error_response()
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
    Error(_) -> error_response()
  }
}

// Error response helpers

fn not_found_response() -> Response {
  html_response(not_found_status(), "<h1>404 Not Found</h1>")
}

fn error_response() -> Response {
  html_response(
    internal_server_error_status(),
    "<h1>500 Internal Server Error</h1>",
  )
}
