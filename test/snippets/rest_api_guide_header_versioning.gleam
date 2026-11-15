//// REST API guide: header-based versioning
////
//// A controller that picks the API version from the `API-Version` header,
//// as shown in docs/guides/rest-api.md.

import dream/context.{type AppContext}
import dream/http.{
  type Request, type Response, bad_request, get_header, json_response, ok,
}
import gleam/option.{unwrap}

pub type Services {
  Services
}

pub fn index(
  request: Request,
  _context: AppContext,
  services: Services,
) -> Response {
  let version =
    get_header(request.headers, "API-Version")
    |> unwrap("1")

  case version {
    "1" -> v1_index(services)
    "2" -> v2_index(services)
    _ -> json_response(bad_request, "{\"error\": \"Unsupported API version\"}")
  }
}

// Implement version-specific controllers
fn v1_index(_services: Services) -> Response {
  json_response(ok, "{\"version\": \"1\"}")
}

fn v2_index(_services: Services) -> Response {
  json_response(ok, "{\"version\": \"2\"}")
}
