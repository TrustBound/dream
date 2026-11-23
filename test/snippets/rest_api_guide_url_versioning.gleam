//// REST API guide: URL-based versioning
////
//// A router that sends each API version to its own controller, as shown in
//// docs/guides/api-patterns.md.

import dream/context.{type AppContext}
import dream/http.{type Request, type Response, json_response, ok}
import dream/http/request.{Get}
import dream/router.{type Router, route, router}

pub type Services {
  Services
}

// router.gleam
pub fn create_router() -> Router(AppContext, Services) {
  router()
  |> route(Get, "/v1/products", list_products_v1, [])
  |> route(Get, "/v2/products", list_products_v2, [])
}

fn list_products_v1(
  _request: Request,
  _context: AppContext,
  _services: Services,
) -> Response {
  json_response(ok, "{\"version\": \"1\"}")
}

fn list_products_v2(
  _request: Request,
  _context: AppContext,
  _services: Services,
) -> Response {
  json_response(ok, "{\"version\": \"2\"}")
}
