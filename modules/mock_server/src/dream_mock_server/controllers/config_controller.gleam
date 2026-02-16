//// config_controller.gleam - Config-mode request handler
////
//// When the mock server is started with a config list, all requests are
//// handled by this controller. It looks up the first matching route by path
//// (exact or prefix) and optional method, and returns that route's status and body.
//// If no route matches, returns 404.

import dream/http/request.{type Request}
import dream/http/response.{type Response, text_response}
import dream/router.{type EmptyServices}
import dream_mock_server/config.{
  type MockConfigContext, type MockRoute, type PathMatch, Exact, Prefix,
}
import gleam/option
import gleam/string

/// Handle a request by finding the first matching route in the config.
/// First match wins (list order). No match returns 404.
pub fn handle(
  request: Request,
  context: MockConfigContext,
  _services: EmptyServices,
) -> Response {
  case find_match(request, context.routes) {
    option.Some(route) -> text_response(route.status, route.body)
    option.None -> text_response(404, "Not found")
  }
}

fn find_match(
  request: Request,
  routes: List(MockRoute),
) -> option.Option(MockRoute) {
  case routes {
    [] -> option.None
    [route, ..rest] -> {
      case route_matches(request, route) {
        True -> option.Some(route)
        False -> find_match(request, rest)
      }
    }
  }
}

fn route_matches(request: Request, route: MockRoute) -> Bool {
  let path_ok = path_matches(request.path, route.path, route.path_match)
  let method_ok = case route.method {
    option.None -> True
    option.Some(m) -> request.method == m
  }
  path_ok && method_ok
}

fn path_matches(
  request_path: String,
  route_path: String,
  path_match: PathMatch,
) -> Bool {
  case path_match {
    Exact -> request_path == route_path
    Prefix -> string.starts_with(request_path, route_path)
  }
}
