//// Products controller demonstrating multi-format responses

import dream/core/http/statuses.{
  bad_request_status, internal_server_error_status, not_found_status,
}
import dream/core/http/transaction.{
  type PathParam, type Request, type Response, get_param, html_response,
}
import dream/utilities/query
import context.{type AppContext}
import services.{type Services}
import sql
import views/products/view as product_view
import gleam/option

/// Show single product - supports .json, .htmx, .csv extensions
/// Also handles /products.json and /products.csv (list with format)
pub fn show(
  request: Request,
  _context: AppContext,
  services: Services,
) -> Response {
  case get_param(request, "id") {
    Error(_) -> bad_request_response()
    Ok(param) -> show_with_param(param, request, services)
  }
}

fn show_with_param(param: PathParam, request: Request, services: Services) -> Response {
  case param.as_int {
    Ok(id) -> show_product(id, param, services)
    Error(_) -> {
      // Not a number - check if it's "products" (list request with format)
      case param.value {
        "products" -> index(request, context.AppContext(request_id: ""), services)
        _ -> bad_request_response()
      }
    }
  }
}

fn show_product(id: Int, param: PathParam, services: Services) -> Response {
  let db = services.database.connection
  case sql.get_product(db, id) |> query.first_row() {
    Ok(product) -> render_product(product, param)
    Error(query.NotFound) -> not_found_response()
    Error(query.DatabaseError) -> error_response()
  }
}

fn render_product(product: sql.GetProductRow, param: PathParam) -> Response {
  product_view.respond(product, param)
}

/// List products - demonstrates streaming for CSV
/// Handles both /products (HTML) and /products.json, /products.csv via id parameter
pub fn index(
  request: Request,
  _context: AppContext,
  services: Services,
) -> Response {
  let db = services.database.connection
  case sql.list_products(db) |> query.all_rows() {
    Ok(products) -> {
      // Check if there's an id parameter (from /products/:id route)
      // If so, it might be "products.json" which should render as list with format
      case get_param(request, "id") {
        Ok(param) -> product_view.respond_list(products, option.Some(param))
        Error(_) -> product_view.respond_list(products, option.None)
      }
    }
    Error(_) -> error_response()
  }
}

// Error response helpers

fn bad_request_response() -> Response {
  html_response(bad_request_status(), "<h1>400 Bad Request</h1>")
}

fn not_found_response() -> Response {
  html_response(not_found_status(), "<h1>404 Not Found</h1>")
}

fn error_response() -> Response {
  html_response(
    internal_server_error_status(),
    "<h1>500 Internal Server Error</h1>",
  )
}
